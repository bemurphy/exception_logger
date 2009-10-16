namespace :exception_logger do
  
  desc "Purge logged exceptions and trackers"
  task :purge => [:purge_exceptions, :purge_trackers]  
  
  desc "Purge the logged_exceptions table"
  task :purge_exceptions do
    $stderr.puts "Would purge le here"
  end
  
  desc "Purge the logged_exception_trackers table"
  task :purge_trackers do
    $stderr.puts "Would purge let here"
  end
  
end