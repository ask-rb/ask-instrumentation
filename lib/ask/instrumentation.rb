require "active_support/notifications"
require_relative "instrumentation/version"

module Ask
  module Instrumentation
    autoload :Chat, "ask/instrumentation/chat"
    autoload :Embedding, "ask/instrumentation/embedding"
    autoload :Tool, "ask/instrumentation/tool"

    class << self
      def subscribe(pattern = /\.ask$/, &block)
        ActiveSupport::Notifications.subscribe(pattern, &block)
      end

      def unsubscribe(subscriber_or_name)
        ActiveSupport::Notifications.unsubscribe(subscriber_or_name)
      end

      def instrument(name, payload = {})
        ActiveSupport::Notifications.instrument(name, payload) { yield if block_given? }
      end

      def with_metadata(metadata = {})
        previous = Thread.current[:ask_instrumentation_metadata]
        Thread.current[:ask_instrumentation_metadata] = (previous || {}).merge(metadata)
        yield
      ensure
        Thread.current[:ask_instrumentation_metadata] = previous
      end

      def current_metadata
        Thread.current[:ask_instrumentation_metadata] || {}
      end
    end
  end
end
