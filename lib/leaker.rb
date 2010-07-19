module Panmind
  module Leaker
    # == DANGER, WILL ROBINSON! ==
    #
    # This code is evil - if you feel you need it, you're probably
    # overlooking Rails' features such as +accepts_nested_attributes_for+
    #
    # Try to avoid it if possible, it is here only because it does
    # interesting things extending rails behaviours.
    #
    # == Usage ==
    #
    # Leaks the given controller +method+ to the model classes array
    # defined in the <tt>:to</tt> option. E.g.:
    #
    #   class FooController < ApplicationController
    #     leaks :current_user, :to => [Bar]
    #   end
    #
    # During the request cycle, an instance of the Bar model will
    # have access to the value returned by the :current_user method
    # in the controller.
    #
    # The special <tt>:all</tt> symbol, passed to the <tt>:to</tt>
    # option, will extend the leak method to *all* +ActiveRecord::Base+
    # and +CouchRest::ExtendedDocument+ (if defined) instances.
    #
    # Use with care! Every time you leak a controller method to a model
    # the Flying Spaghetti Monster kills a kitten. You don't want kittens
    # die, don't you?
    #
    #   - vjt  Mon Jul 19 17:39:05 CEST 2010
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

      if models == :all
        models = [ActiveRecord::Base]
        models.push CouchRest::ExtendedDocument if defined?(CouchRest::ExtendedDocument)
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
        protected thread_key
      end
    end

    module ControllerMethods
      # Returns the currently leaked methods and the respective models they were
      # leaked from, in an Hash form.
      #
      # E.g. if the PostsController leaks :current_user, :to => Post, then
      # PostsController.leakages #=> {:current_user => [Post]}
      #
      def leakages
        read_inheritable_attribute(:leakages) || {}
      end
    end
  end
end
