# frozen_string_literal: true

require "ask/instrumentation"

module Ask
  module Instrumentation
    # Subscribes to an Ask::Runtime::EventSink and re-emits events through
    # Ask::Instrumentation (ActiveSupport::Notifications) with stable names
    # and a uniform payload schema.
    #
    # This is an opt-in adapter: it creates an EventSink that proxies
    # runtime lifecycle events to the instrumentation layer so that
    # existing subscribers (logging, analytics, cost tracking) receive
    # tool execution events without coupling to ask-runtime internals.
    #
    # == Event Mapping
    #
    #   Runtime EventSink type   →   Ask::Instrumentation event name
    #   ─────────────────────────     ──────────────────────────────
    #   :tool_started            →   "tool.started.ask"
    #   :tool_completed          →   "tool.completed.ask"
    #   :tool_failed             →   "tool.failed.ask"
    #   :tool_cancelled          →   "tool.cancelled.ask"
    #   :tool_timed_out          →   "tool.timed_out.ask"
    #
    # == Payload Schema
    #
    # Every emitted event includes:
    #
    #   tool_call_id  [String]  — unique tool-call identifier
    #   tool_name     [String]  — the tool being executed
    #   session_id    [String, nil]  — session correlation
    #   turn          [Integer, nil] — turn number
    #   duration      [Float, nil]   — seconds (nil for ToolStarted)
    #   outcome       [String]       — "success" | "failure" | "cancelled" | "timed_out" | nil (started)
    #   error         [String, nil]  — error message (terminal failures only)
    #   event         [Object]       — the original runtime event object
    #
    # == Usage
    #
    #   require "ask/instrumentation"
    #   require "ask/instrumentation/runtime_adapter"
    #
    #   # One-liner: creates and returns the adapter sink
    #   sink = Ask::Instrumentation.install_runtime_sink
    #
    #   # Or build explicitly
    #   adapter = Ask::Instrumentation::RuntimeAdapter.new
    #   sink = adapter.sink
    #
    #   # Wire into an execution context
    #   ctx = Ask::Runtime::ExecutionContext.new(
    #     session_id: "s_001", turn: 1, event_sink: sink
    #   )
    #
    #   # Later, unsubscribe to stop forwarding
    #   adapter.unsubscribe
    #
    # == Thread Safety
    #
    # The adapter is thread-safe. The underlying EventSink uses a mutex
    # for listener management, and Ask::Instrumentation delegates to
    # ActiveSupport::Notifications which is also thread-safe.
    #
    # == No-Op Safe
    #
    # If ask-runtime is not loaded, install_runtime_sink returns an
    # Ask::Runtime::EventSink.null that discards all events.
    #
    class RuntimeAdapter
      RUNTIME_EVENT_MAP = {
        tool_started: "tool.started.ask",
        tool_completed: "tool.completed.ask",
        tool_failed: "tool.failed.ask",
        tool_cancelled: "tool.cancelled.ask",
        tool_timed_out: "tool.timed_out.ask"
      }.freeze

      attr_reader :sink

      def initialize
        require "ask/runtime"
        @sink = Ask::Runtime::EventSink.new
        @forwarding = true
        @mutex = Mutex.new
        subscribe_all
      end

      # Stop forwarding events to Ask::Instrumentation. The sink continues
      # to exist but events are silently dropped.
      def unsubscribe
        @mutex.synchronize { @forwarding = false }
      end

      # Whether the adapter is currently forwarding events.
      def subscribed?
        @mutex.synchronize { @forwarding }
      end

      private

      def subscribe_all
        RUNTIME_EVENT_MAP.each do |runtime_type, instrumentation_name|
          @sink.on(runtime_type) do |payload|
            next unless @mutex.synchronize { @forwarding }

            forward_event(instrumentation_name, payload)
          end
        end
      end

      def forward_event(name, payload)
        runtime_event = payload[:event]
        return unless runtime_event

        instrument_payload = build_payload(runtime_event)
        Ask::Instrumentation.instrument(name, instrument_payload)
      rescue => e
        # Never let adapter errors break the runtime event pipeline.
        $stderr.puts "[ask-instrumentation] RuntimeAdapter error: #{e.message}" if $DEBUG
      end

      def build_payload(runtime_event)
        base = {
          tool_call_id: runtime_event.tool_call_id,
          tool_name: runtime_event.tool_name,
          session_id: runtime_event.execution_context&.session_id,
          turn: runtime_event.execution_context&.turn,
          event: runtime_event
        }

        # Add duration for terminal events (all except ToolStarted).
        if runtime_event.respond_to?(:duration)
          base[:duration] = runtime_event.duration
        end

        # Classify outcome.
        base[:outcome] = classify_outcome(runtime_event)

        # Attach error for failures.
        if runtime_event.respond_to?(:error)
          base[:error] = runtime_event.error
        elsif runtime_event.respond_to?(:reason)
          base[:error] = runtime_event.reason
        end

        base
      end

      def classify_outcome(runtime_event)
        case runtime_event
        when Ask::Runtime::Events::ToolStarted
          nil
        when Ask::Runtime::Events::ToolCompleted
          "success"
        when Ask::Runtime::Events::ToolFailed
          "failure"
        when Ask::Runtime::Events::ToolCancelled
          "cancelled"
        when Ask::Runtime::Events::ToolTimedOut
          "timed_out"
        else
          nil
        end
      end
    end
  end
end
