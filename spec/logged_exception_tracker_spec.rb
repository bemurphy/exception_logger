require File.dirname(__FILE__) + '/spec_helper'

describe LoggedExceptionTracker do
  before(:each) do
    # ActiveRecord::Base.observers = TracTicketer::LoggedExceptionTrackerObserver.instance
    # TracTicketer.configure {|config| config.trac_url = "http://localhost/trac/xmlrpc"}
    
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
    @tracker = LoggedExceptionTracker.create_from_exception(@controller, @request, @exception, @data)
  end

  describe "dedupe hashing" do
    it "should generate an expected hash" do
      LoggedExceptionTracker.generate_hash(@controller, @exception).should == @expected_hash
    end

    it "should not generate expected hash if the controller name is changed" do
      @controller.should_receive(:controller_name).and_return("some_other_name")
      LoggedExceptionTracker.generate_hash(@controller, @exception).should_not == @expected_hash
    end

    it "should not generate expected hash if the action name is changed" do
      @controller.should_receive(:action_name).and_return("some_other_name")
      LoggedExceptionTracker.generate_hash(@controller, @exception).should_not == @expected_hash
    end

    it "should generate the expected hash if the line number in the backtrace changes" do
      backtrace = @exception.backtrace
      backtrace.first.gsub!(/:\d+:in `/, ":91919191:in `")
      @exception.should_receive(:backtrace).and_return(backtrace)
      LoggedExceptionTracker.generate_hash(@controller, @exception).should == @expected_hash
    end
  end
  
  describe "creation" do
    it "should allow creation from a controller and exception" do
      LoggedExceptionTracker.find(:all).length.should == 1
      LoggedExceptionTracker.find(:first).should == @tracker
    end
    
    it "should not create a new tracker if one already exists" do
      tracker = LoggedExceptionTracker.create_from_exception(@controller, @request, @exception, @data)
      LoggedExceptionTracker.find(:all).length.should == 1
      LoggedExceptionTracker.create_from_exception(@controller, @request, @exception, @data)
      LoggedExceptionTracker.find(:all).length.should == 1
    end
    
    it "should return the stored tracker if called for the same exception" do
      tracker = LoggedExceptionTracker.create_from_exception(@controller, @request, @exception, @data)
      another_tracker = LoggedExceptionTracker.create_from_exception(@controller, @request, @exception, @data)
      tracker.should == another_tracker
    end
    
    it "should create a new logged_exception for a newly tracked exception" do
      LoggedException.count.should == 1
    end
    
    it "should associate a new logged_exception to the already existing tracker if one exists" do
      LoggedException.count.should == 1
      LoggedExceptionTracker.create_from_exception(@controller, @request, @exception, @data)
      LoggedException.count.should == 2
    end
    
    it "should require the hex hash be unique" do
      new_tracker = LoggedExceptionTracker.create(:hex_hash => @tracker.hex_hash)
      new_tracker.errors_on(:hex_hash).should_not be_empty
    end
    
    it "should require a hex hash not be empty" do
      new_tracker = LoggedExceptionTracker.create(:hex_hash => "")
      new_tracker.errors_on(:hex_hash).should_not be_empty
    end
    
    it "should require a hex hash be exactly 32 chars in length" do
      new_tracker = LoggedExceptionTracker.create(:hex_hash => "asfdadf")
      new_tracker.errors_on(:hex_hash).should_not be_empty
    end
    
    it "should require only hex in the hex hash" do
      new_tracker = LoggedExceptionTracker.create(:hex_hash => @expected_hash.gsub(/[a-f]/, 'z'))
      new_tracker.errors_on(:hex_hash).should_not be_empty
    end
    
    it "should be happy with a hex hash that is 32 chars of hex" do
      LoggedExceptionTracker.delete_all
      new_tracker = LoggedExceptionTracker.create(:hex_hash => @expected_hash)
      new_tracker.errors_on(:hex_hash).should be_empty
    end
  end
  
  describe "tracking" do
    it "should be able to report if an exception is already being tracked" do
      LoggedExceptionTracker.already_tracked?(@controller, @exception).should be_true
    end

    it "should be able to report if an exception is not yet tracked" do
      @controller.stub!(:controller_name).and_return("another_controller_name")
      LoggedExceptionTracker.already_tracked?(@controller, @exception).should be_false
    end
  end
  
  describe "associations" do
    it "should require an associated logged exception to be valid" do
      tracker = LoggedExceptionTracker.new(:hex_hash => "A" * 32)
      tracker.should_not be_valid
      tracker.errors_on(:logged_exceptions).should_not be_empty
    end
    
    it "should be valid if it has an associated logged exception" do
      @tracker.should be_valid
      @tracker.error_on(:logged_exceptions).should be_empty
    end
    
    it "should be able to get the first exception associated to the tracker" do
      # Create an extra associated exception so we know that we're getting the first
      LoggedException.count.should == 1
      LoggedExceptionTracker.create_from_exception(@controller, @request, @exception, @data)
      LoggedException.count.should == 2
      @tracker.first_logged_exception.controller_name.should == @controller.controller_name
    end
  end
end