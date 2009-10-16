require "digest/md5"

class LoggedExceptionTracker < ActiveRecord::Base
  has_many :logged_exceptions, :order => "created_at ASC"
  
  validates_presence_of :logged_exceptions
  validates_presence_of :hex_hash
  validates_uniqueness_of :hex_hash
  validates_length_of :hex_hash, :is => 32
  validates_format_of :hex_hash, :with => /^[A-F0-9]+$/i
  
  def self.create_from_exception(controller, request, exception, data)
    hex_hash = generate_hash(controller, exception)
    if tracker = find_or_initialize_by_hex_hash(hex_hash)
      tracker.logged_exceptions << LoggedException.create_from_exception(controller, request, exception, data)
    end
    tracker.save!
    tracker
  end
  
  def self.already_tracked?(controller, exception)
    true & self.find_by_hex_hash(generate_hash(controller, exception))
  end

  def self.generate_hash(controller, exception)
    if matches = exception.backtrace.first.match(/(.+):\d+:in `(.+?)'/)
      Digest::MD5.hexdigest([controller.controller_name, controller.action_name, 
        exception.class.name, matches[1], matches[2]].join(''))
    end
  end
  
  def first_logged_exception
    logged_exceptions.first
  end
end