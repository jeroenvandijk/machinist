require File.dirname(__FILE__) + '/spec_helper'
require 'machinist/active_record'

module MachinistActiveRecordSpecs
  
  class User < ActiveRecord::Base
    attr_protected :secret
    has_and_belongs_to_many :posts
  end
  
  class Person < ActiveRecord::Base
    attr_protected :password
    has_many :subscriptions
    has_many :posts, :through => :subscriptions
  end

  class Subscription < ActiveRecord::Base
    belongs_to :post
    belongs_to :person
  end

  class Post < ActiveRecord::Base
    has_many :comments
    has_many :subscriptions
    has_many :people, :through => :subscriptions
    
    has_and_belongs_to_many :users
  end

  class Comment < ActiveRecord::Base
    belongs_to :post
    belongs_to :author, :class_name => "Person"
  end
  
  

  describe Machinist, "ActiveRecord adapter" do  
    before(:suite) do
      ActiveRecord::Base.logger = Logger.new(File.dirname(__FILE__) + "/log/test.log")
      ActiveRecord::Base.establish_connection(:adapter => "sqlite3", :database => ":memory:")
      load(File.dirname(__FILE__) + "/db/schema.rb")
    end
  
    before(:each) do
      Person.clear_blueprints!
      Post.clear_blueprints!
      Comment.clear_blueprints!

      # We need to truncate the database before each spec
       ActiveRecord::Base.connection.tables.each do |table|
         ActiveRecord::Base.connection.execute("DELETE FROM #{table}")
         ActiveRecord::Base.connection.execute("DELETE FROM sqlite_sequence where name='#{table}'")
       end                                                                                                                               
      ActiveRecord::Base.connection.execute("VACUUM")
      
    end
  
    describe "make method" do
      it "should save the constructed object" do
        Person.blueprint { }
        person = Person.make
        person.should_not be_new_record
      end
  
      it "should create an object through belongs_to association" do
        Post.blueprint { }
        Comment.blueprint { post }
        Comment.make.post.class.should == Post
      end
  
      it "should create an object through belongs_to association with a class_name attribute" do
        Person.blueprint { }
        Comment.blueprint { author }
        Comment.make.author.class.should == Person
      end
      
      it "should allow setting a protected attribute in the blueprint" do
        Person.blueprint do
          password "Test"
        end
        Person.make.password.should == "Test"
      end
      
      it "should allow overriding a protected attribute" do
        Person.blueprint do
          password "Test"
        end
        Person.make(:password => "New").password.should == "New"
      end
      
      it "should allow setting the id attribute in a blueprint" do
        Person.blueprint { id 12345 }
        Person.make.id.should == 12345
      end
      
      it "should allow setting the type attribute in a blueprint" do
        Person.blueprint { type "Person" }
        Person.make.type.should == "Person"
      end

      describe "on a has_many association" do
        before do 
          Post.blueprint { }
          Comment.blueprint { post }
          @post = Post.make
          @comment = @post.comments.make
        end
    
        it "should save the created object" do
          @comment.should_not be_new_record
        end
    
        it "should set the parent association on the created object" do
          @comment.post.should == @post
        end
      end
      
      describe "on a has_and_belongs_to_many assocation" do
        context "in a normal case" do
          before(:each) do
            User.blueprint { name "Fred" }
            Post.blueprint {}
          
            @post = Post.make
            @users = []
            5.times { @users << @post.users.make }
          end
        
          it "should create the right amount of children" do
            @post.users.size.should == 5
          end
        
          it "should save the created objects" do
            @post.users.each{ |user| user.should_not be_new_record }
          end
        
          it "should set the parent association on the created object" do
            @users.each {|user| user.posts.first.should == @post }
          end
        
          it "should set the attributes of the child object" do
            @post.users.each {|user| user.name.should == "Fred" }
          end
        
          it "should not need two queries instead of 1" do
            pending("#create method does not support a block correctly for habtm") do
              @post.users.create do |object|
                object.name = "Fred"
              end

              @post.users.last.name.should == "Fred"
            end
          end
        end
        
        context "with a protected attribute" do
          before(:each) do
            Post.blueprint {}
            User.blueprint { secret "secret" }

            post = Post.make
            post.users.make
          end
          
          it "should set the attribute correctly" do
            Post.all.first.users.first.secret.should == "secret"
          end
        end
      end
      
      describe "on a has_many :through association" do
        context "in a normal case" do
          before(:each) do
            Person.blueprint { }
            Post.blueprint { title "Fred goes wild" }
          
            @person = Person.make
            @post = @person.posts.make
          end
        
          it "should couple the parent to the child object" do
            @post.people.first.should == @person
          end
        
          it "should couple the child to the parent object" do
            @person.posts.first.should == @post
          end
          
          it "should have the same join object" do
            @post.subscriptions.should == @person.subscriptions
          end
        
          it "should set the attributes correctly" do
            @person.posts.first.title.should == "Fred goes wild"
          end
          
          it "should save the created join object" do
            @post.subscriptions.first.should_not be_new_record
          end
        
          it "should save the created object" do
            @person.posts.first.should_not be_new_record
          end
        end
        
        context "with a protected attribute" do
          before(:each) do
            Person.blueprint { password "secret" }
            Post.blueprint {}
            post = Post.make
            post.people.make            
          end

          it "should set the attribute correctly" do
            Post.all.first.people.first.password.should == "secret"
          end
          
        end
        
      end
      

      
    end

    describe "plan method" do
      it "should not save the constructed object" do
        person_count = Person.count
        Person.blueprint { }
        person = Person.plan
        Person.count.should == person_count
      end
  
      it "should create an object through a belongs_to association, and return its id" do
        Post.blueprint { }
        Comment.blueprint { post }
        post_count = Post.count
        comment = Comment.plan
        Post.count.should == post_count + 1
        comment[:post].should be_nil
        comment[:post_id].should_not be_nil
      end
  
      describe "on a has_many association" do
        before do
          Post.blueprint { }
          Comment.blueprint do
            post
            body { "Test" }
          end
          @post = Post.make
          @post_count = Post.count
          @comment = @post.comments.plan
        end
    
        it "should not include the parent in the returned hash" do
          @comment[:post].should be_nil
          @comment[:post_id].should be_nil
        end
    
        it "should not create an extra parent object" do
          Post.count.should == @post_count
        end
      end
    end

    describe "make_unsaved method" do
      it "should not save the constructed object" do
        Person.blueprint { }
        person = Person.make_unsaved
        person.should be_new_record
      end
  
      it "should not save associated objects" do
        Post.blueprint { }
        Comment.blueprint { post }
        comment = Comment.make_unsaved
        comment.post.should be_new_record
      end
  
      it "should save objects made within a passed-in block" do
        Post.blueprint { }
        Comment.blueprint { }
        comment = nil
        post = Post.make_unsaved { comment = Comment.make }
        post.should be_new_record
        comment.should_not be_new_record
      end
    end
  
  end
end
