# Need to fix my gem issues
$LOAD_PATH << "/Library/Ruby/Gems/1.8/gems"
require "trac4r/trac"

module TracTicketer
  class << self
    attr_accessor :trac_url, :trac_username, :trac_password
    attr_writer :trac_reporter
    
    def configure
      yield self
    end
    
    # def trac_port
    #   @trac_port || 80
    # end
    
    def trac_reporter
      @trac_reporter || "exception_logger"
    end
  end # end self
  
  class LoggedExceptionTrackerObserver < ActiveRecord::Observer
    observe LoggedExceptionTracker
    
    def after_create(logged_exception_tracker)
      Ticket.create(logged_exception_tracker)
    end
  end
  
  class Ticket
    def self.create(logged_exception_tracker)
      @exc = logged_exception_tracker.first_logged_exception
      
      trac = Trac.new(TracTicketer.trac_url, TracTicketer.trac_username, TracTicketer.trac_password)

      # TODO: Figure out how I can use ActionView rather than ERB directlyß
      # action_view = ActionView::Base.new(File.dirname(__FILE__) + "/../../views", {})
      # template action_view.render(:file => "observers/_trac_exception.rhtml")
      lines = File.open(File.dirname(__FILE__) + 
              "/../../views/observers/_trac_exception.rhtml"){|f| f.read}
      exception_description = ERB.new(lines).result(binding)
      # puts exception_description
      
      trac.tickets.create("Summary", exception_description, 
                          :reporter => TracTicketer.trac_reporter,
                          :priority => "normal",
                          :type => "defect",
                          :component => @exc.controller_name,
                          :keywords => [@exc.controller_name, @exc.action_name, @exc.exception_class].compact.join(" "))
    end
  end
end