class LoggedExceptionTrackerObserver < ActiveRecord::Observer
  observe LoggedExceptionTracker
  
  def before_create(logged_exception_tracker)
    $stderr.puts logged_exception_tracker.hex_hash
  end
end