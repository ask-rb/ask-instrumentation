require "active_support"
require "active_support/notifications"
require_relative "instrumentation/version"

module Ask
  # Instrumentation for LLM observability in the ask-rb ecosystem.
  #
  # Provides a thin wrapper around +ActiveSupport::Notifications+ for emitting
  # and subscribing to LLM events such as chat completions, embeddings, tool
  # calls, and image generation.
  #
  # Events follow the +{operation}.ask+ naming convention:
  #
  #   chat.ask        # Chat completion
  #   chat.stream.ask # Streaming chat
  #   tool.ask        # Tool execution
  #   embedding.ask   # Embedding generation
  #   image.ask       # Image generation
  #
  # Each event payload includes provider-agnostic keys such as +provider+,
  # +model+, +duration+, and provider-specific metrics (+input_tokens+,
  # +output_tokens+, etc.).
  #
  # == Usage
  #
  #   require "ask/instrumentation"
  #
  #   # Subscribe to all ask events
  #   Ask::Instrumentation.subscribe do |event|
  #     puts "#{event.name}: #{event.duration}ms"
  #   end
  #
  #   # Subscribe with a callable subscriber
  #   Ask::Instrumentation.subscribe(MySubscriber.new)
  #
  #   # Instrument a chat completion
  #   Ask::Instrumentation.instrument("chat.ask", provider: "openai", model: "gpt-4") do
  #     # your LLM call here
  #   end
  #
  #   # Wrap with metadata context
  #   Ask::Instrumentation.with_metadata(user_id: 42, session_id: "abc") do
  #     Ask::Instrumentation.instrument("chat.ask", provider: "openai", model: "gpt-4") do
  #       # ...
  #     end
  #   end
  module Instrumentation
    autoload :Chat, "ask/instrumentation/chat"
    autoload :Embedding, "ask/instrumentation/embedding"
    autoload :Tool, "ask/instrumentation/tool"

    class << self
      # Subscribe to ask instrumentation events.
      #
      # Accepts a callable subscriber (an object that responds to +#call+)
      # and/or a block. When a pattern is given, only events matching the
      # pattern are delivered to the subscriber.
      #
      # @overload subscribe(pattern = /\.ask$/, subscriber)
      #   @param pattern [Regexp, String] Optional event name pattern
      #   @param subscriber [#call] An object that responds to +#call(event)+
      #   @return [ActiveSupport::Notifications::Fanout::Subscriber]
      #
      # @overload subscribe(pattern = /\.ask$/, &block)
      #   @param pattern [Regexp, String] Optional event name pattern
      #   @param block [Proc] The callback invoked on each matching event
      #   @return [ActiveSupport::Notifications::Fanout::Subscriber]
      #
      # @example Subscribe with a block
      #   Ask::Instrumentation.subscribe { |event| puts event.name }
      #
      # @example Subscribe with a callable object
      #   Ask::Instrumentation.subscribe(MySubscriber.new)
      #
      # @example Subscribe with a pattern and callable
      #   Ask::Instrumentation.subscribe(/chat\.ask/, MySubscriber.new)
      def subscribe(pattern = /\.ask$/, subscriber = nil, &block)
        ActiveSupport::Notifications.subscribe(pattern, subscriber || block)
      end

      # Unsubscribe from events.
      #
      # Delegates to +ActiveSupport::Notifications.unsubscribe+. Accepts either
      # the subscriber object returned from {subscribe} or a string/regexp
      # pattern.
      #
      # @param subscriber_or_name [ActiveSupport::Notifications::Fanout::Subscriber, String, Regexp]
      #   The subscriber to remove
      # @return [void]
      #
      # @example
      #   subscriber = Ask::Instrumentation.subscribe { |e| puts e.name }
      #   Ask::Instrumentation.unsubscribe(subscriber)
      def unsubscribe(subscriber_or_name)
        ActiveSupport::Notifications.unsubscribe(subscriber_or_name)
      end

      # Instrument a block of code, wrapping it in an +ActiveSupport::Notifications+ event.
      #
      # The event name should follow the +{operation}.ask+ convention.
      # The payload is automatically merged with the current thread metadata
      # (set via {with_metadata}) before being emitted.
      #
      # @param name [String] The event name (e.g. +"chat.ask"+)
      # @param payload [Hash] The event payload
      # @yield The block to instrument
      # @return [Object] The return value of the block
      #
      # @example
      #   Ask::Instrumentation.instrument("chat.ask", provider: "openai", model: "gpt-4") do
      #     # LLM call
      #   end
      def instrument(name, payload = {})
        merged = current_metadata.merge(payload)
        ActiveSupport::Notifications.instrument(name, merged) { yield if block_given? }
      end

      # Execute a block with thread-local metadata that gets merged into all
      # events emitted within the block.
      #
      # Nested calls merge the inner metadata into the outer, with the inner
      # values taking precedence for duplicate keys. The outer metadata is
      # restored after the inner block completes.
      #
      # Metadata is useful for attaching context such as +user_id+,
      # +session_id+, +request_id+, or +trace_id+ to every event.
      #
      # @param metadata [Hash] The metadata hash to attach
      # @yield The block to execute with the metadata context
      # @return [Object] The return value of the block
      #
      # @example
      #   Ask::Instrumentation.with_metadata(user_id: 42) do
      #     Ask::Instrumentation.instrument("chat.ask", provider: "openai", model: "gpt-4") do
      #       # ... event payload will include user_id: 42
      #     end
      #   end
      def with_metadata(metadata = {})
        previous = Thread.current[:ask_instrumentation_metadata]
        Thread.current[:ask_instrumentation_metadata] = (previous || {}).merge(metadata)
        yield
      ensure
        Thread.current[:ask_instrumentation_metadata] = previous
      end

      # Return the current thread's metadata hash.
      #
      # This is the metadata hash that will be merged into any event payload
      # emitted via {instrument} in the current thread.
      #
      # @return [Hash] The current metadata (empty hash if none set)
      #
      # @example
      #   Ask::Instrumentation.current_metadata # => {}
      #   Ask::Instrumentation.with_metadata(user_id: 42) do
      #     Ask::Instrumentation.current_metadata # => { user_id: 42 }
      #   end
      def current_metadata
        Thread.current[:ask_instrumentation_metadata] || {}
      end
    end
  end
end
