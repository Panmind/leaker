module PM
  module Leaker
    module PluginMethods
      # Leaks the given controller +method+ to the model classes array
      # defined in the <tt>:to</tt> option. E.g.:
      #
      # class PippoController < ApplicationController
      #   leaks :current_user, :to => [Pippo]
      # end
      #
      # During the request cycle, an instance of the Pippo model will
      # have access to the value returned by the :current_user in the
      # controller.
      #
      # The special <tt>:all</tt> symbol, passed to the <tt>:to</tt>
      # option, will extend the leak method to *all* ActiveRecord::Base
      # instances. Use with care!
      #
      def leaks(method, options)
        controller = self
        unless controller <= ActionController::Base
          raise ArgumentError,
            "Leakage: #{controller.inspect} must be an ActionController"
        end

        models = options.delete(:to)
        if models.nil?
          raise ArgumentError, 'Leakage: :to => [Model {, Model ... } ] is required'
        end

        models = [ActiveRecord::Base] if models == :all
        unless models.all? { |model| model <= ActiveRecord::Base }
          raise ArgumentError, "Leakage: All classes in :to must be ActiveRecords"
        end

        models.reject! do |model|
          if model.respond_to?(method)
            Rails.logger.warn "Leakage: #{model.name} already responds to #{method}, skipped"
            true
          end
        end

        extend ControllerMethods unless self.respond_to?(:leakages) 

        if leakages.include?(method)
          receivers = leakages[method].map(&:name).join(', ')
          raise RuntimeError, "Leakage: #{method} is already leaked to #{receivers}"
        end

        write_inheritable_attribute(:leakages, leakages.merge(method => models))

        thread_key = "leak_#{method}_#{rand(0xffff)}"
        models.each do |model|
          model.class_eval do
            define_method(method) { Thread.current[thread_key] }
          end
        end

        controller.class_eval do
          before_filter thread_key
          define_method(thread_key) { Thread.current[thread_key] = send(method) }
        end
      end
    end

    module ControllerMethods
      def leakages
        read_inheritable_attribute(:leakages) || {}
      end
    end
  end
end

ActionController::Base.extend PM::Leaker::PluginMethods
