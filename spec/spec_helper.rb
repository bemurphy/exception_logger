begin
  require File.dirname(__FILE__) + '/../../../../spec/spec_helper'
rescue LoadError
  puts "You need to install rspec in your base app"
  exit
end

plugin_spec_dir = File.dirname(__FILE__)
ActiveRecord::Base.logger = Logger.new(plugin_spec_dir + "/debug.log")

require "observers/trac_ticketer"

module LoggedExceptionTrackerHelper
  def setup_exception_data
    @request = ActionController::TestRequest.new
    @controller = mock(ActionController::Base.new,
    :controller_name => "spec_example_controller",
    :action_name => "do_raise",
    :request => @request)
    @controller.stub!(:do_raise).and_raise(StandardError.new("spec example exception message"))
    @data = ""

    @exception = begin
      @controller.do_raise
    rescue => caught_exception
      caught_exception
    end
    @expected_hash = "8d298f2fb359cafdec9a6a28e70c9549"
    @tracker = LoggedExceptionTracker.create_from_exception(@controller, @exception, @data)
  end  
end