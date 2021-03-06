require 'machinist'
require 'machinist/blueprints'

module Machinist
  
  class ActiveRecordAdapter
    
    def self.has_association?(object, attribute)
      object.class.reflect_on_association(attribute)
    end
    
    def self.class_for_association(object, attribute)
      association = object.class.reflect_on_association(attribute)
      association && association.klass
    end
    
    # This method takes care of converting any associated objects,
    # in the hash returned by Lathe#assigned_attributes, into their
    # object ids.
    #
    # For example, let's say we have blueprints like this:
    #
    #   Post.blueprint { }
    #   Comment.blueprint { post }
    #
    # Lathe#assigned_attributes will return { :post => ... }, but
    # we want to pass { :post_id => 1 } to a controller.
    #
    # This method takes care of cleaning this up.
    def self.assigned_attributes_without_associations(lathe)
      attributes = {}
      lathe.assigned_attributes.each_pair do |attribute, value|
        association = lathe.object.class.reflect_on_association(attribute)
        if association && association.macro == :belongs_to
          attributes[association.primary_key_name.to_sym] = value.id
        else
          attributes[attribute] = value
        end
      end
      attributes
    end
    
  end
    
  module ActiveRecordExtensions
    def self.included(base)
      base.extend(ClassMethods)
    end
  
    module ClassMethods
      def make(*args, &block)
        lathe = Lathe.run(Machinist::ActiveRecordAdapter, self.new, *args)
        unless Machinist.nerfed?
          lathe.object.save!
          lathe.object.reload
        end
        lathe.object(&block)
      end

      def make_unsaved(*args)
        returning(Machinist.with_save_nerfed { make(*args) }) do |object|
          yield object if block_given?
        end
      end
        
      def plan(*args)
        lathe = Lathe.run(Machinist::ActiveRecordAdapter, self.new, *args)
        Machinist::ActiveRecordAdapter.assigned_attributes_without_associations(lathe)
      end
    end
  end
  
  module ActiveRecordAssociationCollectionExtensions
    def make(*args, &block)
     instance = Machinist.nerfed? ? self.build : self.new
     lathe = Lathe.run(Machinist::ActiveRecordAdapter, instance, *args)
     
      unless Machinist.nerfed?
        # We are calling create here instead of build and save because they do not work correctly on habtm associations, this also means we can't call build early
        attributes_to_assign = lathe.object.attributes.slice(*column_names)
        
        created_instance = create!(attributes_to_assign)
        attributes_to_assign.each_pair { |method, value|  
          created_instance.send("#{method}=", value) # to set the all the protected attributes
        }
        if created_instance.changed? # Unfortunately we have to do another query if we have accessed protected methods
          created_instance.save! 
          created_instance.reload
        end
        lathe.instance_eval { @object = created_instance }
      end
      lathe.object(&block)
    end

    def plan(*args)
      lathe = Lathe.run(Machinist::ActiveRecordAdapter, self.build, *args)
      Machinist::ActiveRecordAdapter.assigned_attributes_without_associations(lathe)
    end
  end

end

class ActiveRecord::Base
  include Machinist::Blueprints
  include Machinist::ActiveRecordExtensions
end

class ActiveRecord::Associations::AssociationCollection
  include Machinist::ActiveRecordAssociationCollectionExtensions
end
