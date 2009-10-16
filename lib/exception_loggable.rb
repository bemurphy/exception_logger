require 'ipaddr'

# Copyright (c) 2005 Jamis Buck
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
module ExceptionLoggable
  def self.included(base)
    base.send(:alias_method, :original_rescue_action_in_public, :rescue_action_in_public)
    base.send(:alias_method, :rescue_action_in_public, :rescue_action_in_public_with_loggable)
    base.extend(ClassMethods)
  end

  module ClassMethods
    if respond_to?(:method_added)
      alias_method :original_method_added, :method_added
    end
    
    def method_added(method_sym)
      original_method_added(method_sym) if respond_to?(:original_method_added)
        
      return if instance_methods.map(&:to_s).include?("original_rescue_action_in_public")
      
      if method_sym == :rescue_action_in_public
        alias_method :original_rescue_action_in_public, :rescue_action_in_public
        alias_method :rescue_action_in_public, :rescue_action_in_public_with_loggable
      end
    end
    
    def consider_local(*args)
      local_addresses.concat(args.flatten.map { |a| IPAddr.new(a) })
    end

    def local_addresses
      addresses = read_inheritable_attribute(:local_addresses)
      unless addresses
        addresses = [IPAddr.new("127.0.0.1")]
        write_inheritable_attribute(:local_addresses, addresses)
      end
      addresses
    end

    def exception_data(deliverer = self, &block)
      deliverer = block if block
      if deliverer == self
        read_inheritable_attribute(:exception_data)
      else
        write_inheritable_attribute(:exception_data, deliverer)
      end
    end
  end
  
  protected
  
  def local_request?
    return false
    # remote = IPAddr.new(request.remote_ip)
    # !self.class.local_addresses.detect { |addr| addr.include?(remote) }.nil?
  end

  def rescue_action_in_public_with_loggable(exception)
    status = response_code_for_rescue(exception)
    # TODO: figure out why this was originally here
    # Since I'm chaining to the original rescue_action_in_public now, we don't want
    # to render 2x
    # render_optional_error_file status
    log_exception(exception) if status != :not_found
    original_rescue_action_in_public(exception)
  end
    
  def log_exception(exception)
    deliverer = self.class.exception_data
    data = case deliverer
      when nil    then {}
      when Symbol then send(deliverer)
      when Proc   then deliverer.call(self)
    end
    
    # It's kind of redundant to pass in controller and a filtered request, but, I don't want
    # to monkey with the running controller.  The other option would be a controller proxy,
    # but that feels like overkill
    filter_request_proxy = FilterRequestProxy.new(request, filtered_sensitive_parameters, filtered_sensitive_env)
    # filtered_controller_proxy = FilterControllerProxy.new(self, filtered_sensitive_parameters, filtered_sensitive_env)
    LoggedExceptionTracker.create_from_exception(self, filter_request_proxy, exception, data)
  end
  
  module ExceptionLoggableProxy
    instance_methods.each { |m| undef_method m unless m =~ /(^__|^send$|^object_id$)/ }

    def initialize(target, f_params, f_env)
      @target = target
      @f_params = f_params
      @f_env = f_env
    end
    
    protected
    def method_missing(name, *args, &block)
      @target.send(name, *args, &block)
    end
    public
  end
  
  # Not even close
  # class FilterControllerProxy    
  #   include ExceptionLoggableProxy
  #   
  #   def initialize(target, f_params, f_env)
  #     super
  #     
  #     if @target.respond_to?(:filter_parameters)
  #       def request
  #         return @filter_controller_proxy if defined?(@filter_controller_proxy)
  #         real_request = @target.send(name, *args, &block)
  #         @filter_controller_proxy = FilterControllerProxy.new(real_request, @f_params, @f_env)        
  #       end
  #     end
  #   end    
  # end
  
  class FilterRequestProxy
    include ExceptionLoggableProxy
    
    def parameters
      @f_params
    end
    
    def env
      @f_env
    end
  end
    
  def filter_parameters?
    respond_to?(:filter_parameters)
  end
  
  def filtered_sensitive_parameters
    filter_parameters? ? filter_parameters(request.params) : request.params
  end
  
  def filtered_sensitive_env
    mutuable_env = request.env.dup
    mutuable_env.each {|key, value| mutuable_env[key] = '[FILTERED]' if key =~ /RAW_POST_DATA/i}
  end
  
end