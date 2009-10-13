# Need to fix my gem issues
$LOAD_PATH << "/Library/Ruby/Gems/1.8/gems"
require "trac4r/trac"

module TracTicketer
  class << self
    attr_accessor :trac_url, :trac_username, :trac_password
    attr_writer :trac_port, :trac_reporter
    
    def configure
      yield self
    end
    
    def trac_port
      @trac_port || 80
    end
    
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
      logged_exception = logged_exception_tracker.first_logged_exception
      
      trac = Trac.new(TracTicketer.trac_url, TracTicketer.trac_username, TracTicketer.trac_password)
      trac.tickets.create("Summary", "Description", 
                          :reporter => TracTicketer.trac_reporter,
                          :type => "defect")
    end
  end
end