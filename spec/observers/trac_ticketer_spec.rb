require File.dirname(__FILE__) + '/../spec_helper'

describe TracTicketer do
  include LoggedExceptionTrackerHelper
  
  before(:each) do
    @default_trac_url = "http://localhost/trac/xmlrpc"
    @tickets_mock = mock("tickets", :create => true)
    @trac_mock = mock("trac", :tickets => @tickets_mock)
    Trac.stub!(:new).and_return(@trac_mock)
    TracTicketer.configure do |config| 
      config.trac_url = @default_trac_url
      config.trac_username = nil
      config.trac_password = nil
    end
  end
  
  describe "configuration" do
    it "should allow configuration of the trac url" do
      TracTicketer.configure {|config| config.trac_url = "example_trac_url"}
      TracTicketer.trac_url.should == "example_trac_url"
    end

    it "should have 80 as the default trac port" do
      TracTicketer.trac_port.should == 80
    end
    
    it "should allow configuration of the trac port" do
      TracTicketer.configure {|config| config.trac_port = 9191}
      TracTicketer.trac_port.should == 9191
    end

    it "should allow configuration of the trac username" do
      TracTicketer.configure {|config| config.trac_username = "example_spec_username"}
      TracTicketer.trac_username.should == "example_spec_username"
    end
    
    it "should allow configuration of the trac password" do
      TracTicketer.configure {|config| config.trac_password = "example_spec_password"}
      TracTicketer.trac_password = "example_spec_password"
    end
    
    it "should have exception_logger as the default trac reporter" do
      TracTicketer.trac_reporter.should == "exception_logger"
    end
    
    it "should allow configuration of the trac reporter" do
      TracTicketer.configure {|config| config.trac_reporter = "example_spec_reporter"}
      TracTicketer.trac_reporter.should == "example_spec_reporter"
    end
  end
  
  describe TracTicketer::LoggedExceptionTrackerObserver do
    before(:each) do
      ActiveRecord::Base.observers = TracTicketer::LoggedExceptionTrackerObserver.instance
      @observer = TracTicketer::LoggedExceptionTrackerObserver.instance
    end
    
    after(:each) do
      # TODO figure out how to remove the observer
      # ActiveRecord::Base.observers = nil
    end

    it "should have an after_create hook" do
      @observer.should respond_to(:after_create)
    end

    it "should observe the LoggedExceptionTracker model" do
      pending("Getting weird unknown const error I need to fig")
      puts TracTicketer::LoggedExceptionTrackerObserver.observed_class
    end
  end
  
  describe TracTicketer::Ticket do
    before(:each) do
      setup_exception_data
    end
    
    describe "create" do
      it "should create a trac object with the expected url" do
        Trac.should_receive(:new).with(@default_trac_url, nil, nil).and_return(@trac_mock)
        TracTicketer::Ticket.create(@tracker)
      end
      
      it "should pass the username and password to trac if present" do
        TracTicketer.configure do |config|
          config.trac_username = "123"
          config.trac_password = "456"
        end
        
        Trac.should_receive(:new).with(@default_trac_url, "123", "456").and_return(@trac_mock)
        TracTicketer::Ticket.create(@tracker)
      end
      
      it "should pass the expected values to create a trac ticket" do
        @tickets_mock.should_receive(:create).with({})
        TracTicketer::Ticket.create(@tracker)
      end
    end
  end
end