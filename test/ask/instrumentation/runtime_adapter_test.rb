# frozen_string_literal: true

require_relative "../../test_helper"
require "ask/instrumentation"
require "ask/instrumentation/runtime_adapter"
require "ask/runtime"
require "stringio"

class RuntimeAdapterEventMappingTest < Minitest::Test
  def setup
    @events = []
    @subscriber = Ask::Instrumentation.subscribe do |event|
      @events << event
    end
    @adapter = Ask::Instrumentation::RuntimeAdapter.new
    @sink = @adapter.sink
  end

  def teardown
    @adapter.unsubscribe
    Ask::Instrumentation.unsubscribe(@subscriber)
  end

  def test_tool_started_maps_to_tool_started_ask
    event = build_tool_started_event
    @sink.emit(:tool_started, event: event)

    assert_equal 1, @events.length
    assert_equal "tool.started.ask", @events.first.name
  end

  def test_tool_completed_maps_to_tool_completed_ask
    event = build_tool_completed_event
    @sink.emit(:tool_completed, event: event)

    assert_equal 1, @events.length
    assert_equal "tool.completed.ask", @events.first.name
  end

  def test_tool_failed_maps_to_tool_failed_ask
    event = build_tool_failed_event
    @sink.emit(:tool_failed, event: event)

    assert_equal 1, @events.length
    assert_equal "tool.failed.ask", @events.first.name
  end

  def test_tool_cancelled_maps_to_tool_cancelled_ask
    event = build_tool_cancelled_event
    @sink.emit(:tool_cancelled, event: event)

    assert_equal 1, @events.length
    assert_equal "tool.cancelled.ask", @events.first.name
  end

  def test_tool_timed_out_maps_to_tool_timed_out_ask
    event = build_tool_timed_out_event
    @sink.emit(:tool_timed_out, event: event)

    assert_equal 1, @events.length
    assert_equal "tool.timed_out.ask", @events.first.name
  end

  def test_all_five_event_types_are_mapped
    @sink.emit(:tool_started, event: build_tool_started_event)
    @sink.emit(:tool_completed, event: build_tool_completed_event)
    @sink.emit(:tool_failed, event: build_tool_failed_event)
    @sink.emit(:tool_cancelled, event: build_tool_cancelled_event)
    @sink.emit(:tool_timed_out, event: build_tool_timed_out_event)

    names = @events.map(&:name)
    assert_equal %w[
      tool.started.ask
      tool.completed.ask
      tool.failed.ask
      tool.cancelled.ask
      tool.timed_out.ask
    ], names
  end

  def test_unrelated_event_types_are_not_forwarded
    @sink.emit(:custom_event, event: "something")
    @sink.emit(:another_event, event: "other")

    assert @events.empty?
  end

  def test_emit_with_nil_event_does_not_raise
    @sink.emit(:tool_started, event: nil)
    assert @events.empty?
  end

  def test_emit_without_event_key_does_not_raise
    @sink.emit(:tool_completed, foo: "bar")
    assert @events.empty?
  end
end

class RuntimeAdapterPayloadSchemaTest < Minitest::Test
  def setup
    @events = []
    @subscriber = Ask::Instrumentation.subscribe do |event|
      @events << event
    end
    @adapter = Ask::Instrumentation::RuntimeAdapter.new
    @sink = @adapter.sink
  end

  def teardown
    @adapter.unsubscribe
    Ask::Instrumentation.unsubscribe(@subscriber)
  end

  def test_started_payload_includes_tool_call_id
    event = build_tool_started_event
    @sink.emit(:tool_started, event: event)

    payload = @events.first.payload
    assert_equal "tc_abc123", payload[:tool_call_id]
  end

  def test_started_payload_includes_tool_name
    event = build_tool_started_event
    @sink.emit(:tool_started, event: event)

    payload = @events.first.payload
    assert_equal "search", payload[:tool_name]
  end

  def test_started_payload_includes_session_id
    event = build_tool_started_event
    @sink.emit(:tool_started, event: event)

    payload = @events.first.payload
    assert_equal "s_001", payload[:session_id]
  end

  def test_started_payload_includes_turn
    event = build_tool_started_event
    @sink.emit(:tool_started, event: event)

    payload = @events.first.payload
    assert_equal 3, payload[:turn]
  end

  def test_started_payload_duration_is_nil
    event = build_tool_started_event
    @sink.emit(:tool_started, event: event)

    payload = @events.first.payload
    assert_nil payload[:duration]
  end

  def test_started_payload_outcome_is_nil
    event = build_tool_started_event
    @sink.emit(:tool_started, event: event)

    payload = @events.first.payload
    assert_nil payload[:outcome]
  end

  def test_started_payload_includes_original_event
    event = build_tool_started_event
    @sink.emit(:tool_started, event: event)

    payload = @events.first.payload
    assert_same event, payload[:event]
  end

  def test_completed_payload_has_success_outcome
    event = build_tool_completed_event
    @sink.emit(:tool_completed, event: event)

    payload = @events.first.payload
    assert_equal "success", payload[:outcome]
  end

  def test_completed_payload_includes_duration
    event = build_tool_completed_event
    @sink.emit(:tool_completed, event: event)

    payload = @events.first.payload
    assert_equal 1.5, payload[:duration]
  end

  def test_failed_payload_has_failure_outcome
    event = build_tool_failed_event
    @sink.emit(:tool_failed, event: event)

    payload = @events.first.payload
    assert_equal "failure", payload[:outcome]
  end

  def test_failed_payload_includes_error
    event = build_tool_failed_event
    @sink.emit(:tool_failed, event: event)

    payload = @events.first.payload
    assert_equal "file not found", payload[:error]
  end

  def test_cancelled_payload_has_cancelled_outcome
    event = build_tool_cancelled_event
    @sink.emit(:tool_cancelled, event: event)

    payload = @events.first.payload
    assert_equal "cancelled", payload[:outcome]
  end

  def test_cancelled_payload_includes_error_from_reason
    event = build_tool_cancelled_event
    @sink.emit(:tool_cancelled, event: event)

    payload = @events.first.payload
    assert_equal "Aborted by sibling", payload[:error]
  end

  def test_timed_out_payload_has_timed_out_outcome
    event = build_tool_timed_out_event
    @sink.emit(:tool_timed_out, event: event)

    payload = @events.first.payload
    assert_equal "timed_out", payload[:outcome]
  end

  def test_timed_out_payload_includes_duration
    event = build_tool_timed_out_event
    @sink.emit(:tool_timed_out, event: event)

    payload = @events.first.payload
    assert_equal 30.0, payload[:duration]
  end

  def test_payload_preserves_session_correlation
    event = build_tool_completed_event(session_id: "s_999", turn: 7)
    @sink.emit(:tool_completed, event: event)

    payload = @events.first.payload
    assert_equal "s_999", payload[:session_id]
    assert_equal 7, payload[:turn]
  end
end

class RuntimeAdapterSubscribeUnsubscribeLifecycleTest < Minitest::Test
  def test_adapter_is_subscribed_after_creation
    adapter = Ask::Instrumentation::RuntimeAdapter.new
    assert adapter.subscribed?
    adapter.unsubscribe
  end

  def test_adapter_stops_forwarding_after_unsubscribe
    events = []
    subscriber = Ask::Instrumentation.subscribe { |e| events << e }

    adapter = Ask::Instrumentation::RuntimeAdapter.new
    sink = adapter.sink

    sink.emit(:tool_started, event: build_tool_started_event)
    assert_equal 1, events.length

    adapter.unsubscribe

    sink.emit(:tool_completed, event: build_tool_completed_event)
    assert_equal 1, events.length, "No new events after unsubscribe"

    Ask::Instrumentation.unsubscribe(subscriber)
  end

  def test_unsubscribe_is_idempotent
    adapter = Ask::Instrumentation::RuntimeAdapter.new
    adapter.unsubscribe
    adapter.unsubscribe # should not raise
    refute adapter.subscribed?
  end

  def test_sink_continues_to_exist_after_unsubscribe
    adapter = Ask::Instrumentation::RuntimeAdapter.new
    sink = adapter.sink
    received = []
    sink.on(:tool_started) { |e| received << e[:event] }

    adapter.unsubscribe

    sink.emit(:tool_started, event: build_tool_started_event)
    # Sink listeners still fire, but adapter doesn't forward to AS::Notifications
    assert_equal 1, received.length, "Sink listeners still work"
  end

  def test_multiple_adapters_are_independent
    events = []
    subscriber = Ask::Instrumentation.subscribe { |e| events << e }

    adapter1 = Ask::Instrumentation::RuntimeAdapter.new
    adapter2 = Ask::Instrumentation::RuntimeAdapter.new

    adapter1.sink.emit(:tool_started, event: build_tool_started_event)
    adapter2.sink.emit(:tool_completed, event: build_tool_completed_event)

    # Both adapters emit to the same global AS::Notifications, so subscriber sees all
    assert_equal 2, events.length
    assert_equal "tool.started.ask", events[0].name
    assert_equal "tool.completed.ask", events[1].name

    # Unsubscribing adapter1 stops only adapter1
    adapter1.unsubscribe
    events.clear

    adapter1.sink.emit(:tool_started, event: build_tool_started_event)
    adapter2.sink.emit(:tool_completed, event: build_tool_completed_event)

    assert_equal 1, events.length, "Only adapter2's event forwarded"
    assert_equal "tool.completed.ask", events.first.name

    adapter1.unsubscribe
    adapter2.unsubscribe
    Ask::Instrumentation.unsubscribe(subscriber)
  end

  def test_resubscribe_after_unsubscribe
    events = []
    subscriber = Ask::Instrumentation.subscribe { |e| events << e }

    adapter = Ask::Instrumentation::RuntimeAdapter.new
    adapter.unsubscribe
    adapter.unsubscribe # idempotent

    # Cannot resubscribe (design choice: one-shot lifecycle)
    # But we can create a new adapter
    adapter2 = Ask::Instrumentation::RuntimeAdapter.new
    adapter2.sink.emit(:tool_started, event: build_tool_started_event)

    assert_equal 1, events.length
    assert_equal "tool.started.ask", events.first.name

    adapter2.unsubscribe
    Ask::Instrumentation.unsubscribe(subscriber)
  end
end

class RuntimeAdapterErrorHandlingTest < Minitest::Test
  def setup
    @events = []
    @subscriber = Ask::Instrumentation.subscribe do |event|
      @events << event
    end
    @adapter = Ask::Instrumentation::RuntimeAdapter.new
    @sink = @adapter.sink
  end

  def teardown
    @adapter.unsubscribe
    Ask::Instrumentation.unsubscribe(@subscriber)
  end

  def test_broken_subscriber_does_not_crash_adapter
    # Register a subscriber that raises
    broken_subscriber = Ask::Instrumentation.subscribe do |_event|
      raise "subscriber exploded"
    end

    # The adapter should not crash — AS::Notifications propagates subscriber
    # errors, but the adapter itself handles its own errors.
    # We test that the adapter method itself doesn't raise for normal events.
    @sink.emit(:tool_started, event: build_tool_started_event)

    # The event was emitted (and the broken subscriber may have raised,
    # but that's AS::Notifications' problem, not the adapter's)
    Ask::Instrumentation.unsubscribe(broken_subscriber)
  end

  def test_adapter_handles_event_with_missing_context_fields
    call = Ask::Runtime::ToolCall.new(
      tool_name: "test", input: {}
    )
    ctx = Ask::Runtime::ExecutionContext.new
    event = Ask::Runtime::Events::ToolStarted.new(
      tool_call: call, execution_context: ctx, timestamp: Time.now
    )

    @sink.emit(:tool_started, event: event)

    assert_equal 1, @events.length
    payload = @events.first.payload
    assert_nil payload[:session_id]
    assert_nil payload[:turn]
  end

  def test_error_message_logged_in_debug_mode
    original_debug = $DEBUG
    $DEBUG = true

    stderr_output = capture_stderr do
      # Force an error by mocking
      @adapter.stub(:build_payload, ->(_) { raise "boom" }) do
        @sink.emit(:tool_started, event: build_tool_started_event)
      end
    end

    assert_match(/RuntimeAdapter error: boom/, stderr_output)
  ensure
    $DEBUG = original_debug
  end
end

class RuntimeAdapterParallelEventsTest < Minitest::Test
  def test_parallel_emits_produce_correct_event_count
    events = []
    subscriber = Ask::Instrumentation.subscribe { |e| events << e }

    adapter = Ask::Instrumentation::RuntimeAdapter.new
    sink = adapter.sink

    threads = 4.times.map do |i|
      Thread.new do
        25.times do |j|
          sink.emit(:tool_started, event: build_tool_started_event(
            id: "tc_#{i}_#{j}", name: "tool_#{i}"
          ))
        end
      end
    end

    threads.each(&:join)

    assert_equal 100, events.length
    events.each do |e|
      assert_equal "tool.started.ask", e.name
    end

    adapter.unsubscribe
    Ask::Instrumentation.unsubscribe(subscriber)
  end

  def test_parallel_terminal_events_are_independent
    events = []
    subscriber = Ask::Instrumentation.subscribe { |e| events << e }

    adapter = Ask::Instrumentation::RuntimeAdapter.new
    sink = adapter.sink

    terminal_types = [:tool_completed, :tool_failed, :tool_cancelled, :tool_timed_out]
    threads = 4.times.map do |i|
      Thread.new do
        10.times do |j|
          event_type = terminal_types[i]
          sink.emit(event_type, event: build_terminal_event(event_type, id: "tc_#{i}_#{j}"))
        end
      end
    end

    threads.each(&:join)

    assert_equal 40, events.length
    expected_names = %w[
      tool.completed.ask
      tool.failed.ask
      tool.cancelled.ask
      tool.timed_out.ask
    ]
    assert_equal expected_names.sort, events.map(&:name).sort.uniq.sort

    adapter.unsubscribe
    Ask::Instrumentation.unsubscribe(subscriber)
  end

  def test_start_and_terminal_events_can_interleave
    events = []
    subscriber = Ask::Instrumentation.subscribe { |e| events << e }

    adapter = Ask::Instrumentation::RuntimeAdapter.new
    sink = adapter.sink

    t1 = Thread.new do
      50.times { sink.emit(:tool_started, event: build_tool_started_event(id: "tc_a")) }
    end
    t2 = Thread.new do
      50.times { sink.emit(:tool_completed, event: build_tool_completed_event(id: "tc_b")) }
    end

    t1.join
    t2.join

    started = events.select { |e| e.name == "tool.started.ask" }
    completed = events.select { |e| e.name == "tool.completed.ask" }

    assert_equal 50, started.length
    assert_equal 50, completed.length

    adapter.unsubscribe
    Ask::Instrumentation.unsubscribe(subscriber)
  end

  def test_unsubscribe_drops_events_concurrently
    events = []
    subscriber = Ask::Instrumentation.subscribe { |e| events << e }

    adapter = Ask::Instrumentation::RuntimeAdapter.new
    sink = adapter.sink

    # Start forwarding
    t1 = Thread.new do
      20.times { sink.emit(:tool_started, event: build_tool_started_event(id: "tc_fwd")) }
    end
    t1.join

    adapter.unsubscribe

    # After unsubscribe, no new events should be forwarded
    t2 = Thread.new do
      20.times { sink.emit(:tool_completed, event: build_tool_completed_event(id: "tc_stop")) }
    end
    t2.join

    completed = events.select { |e| e.name == "tool.completed.ask" }
    assert_equal 0, completed.length, "No events forwarded after unsubscribe"

    Ask::Instrumentation.unsubscribe(subscriber)
  end
end

class RuntimeAdapterInstallHelperTest < Minitest::Test
  def test_install_runtime_sink_returns_event_sink
    sink = Ask::Instrumentation.install_runtime_sink
    assert_instance_of Ask::Runtime::EventSink, sink
  end

  def test_install_runtime_sink_creates_working_bridge
    events = []
    subscriber = Ask::Instrumentation.subscribe { |e| events << e }

    sink = Ask::Instrumentation.install_runtime_sink
    sink.emit(:tool_started, event: build_tool_started_event)

    assert_equal 1, events.length
    assert_equal "tool.started.ask", events.first.name

    Ask::Instrumentation.unsubscribe(subscriber)
  end
end

private

def build_tool_call(**overrides)
  defaults = {
    id: "tc_abc123",
    tool_name: "search",
    input: { query: "test" },
    session_id: "s_001",
    turn: 3
  }
  Ask::Runtime::ToolCall.new(**defaults.merge(overrides))
end

def build_execution_context(**overrides)
  defaults = {
    session_id: "s_001",
    turn: 3
  }
  Ask::Runtime::ExecutionContext.new(**defaults.merge(overrides))
end

def build_tool_started_event(**overrides)
  call_overrides = {}
  ctx_overrides = {}
  call_overrides[:id] = overrides.delete(:id) if overrides.key?(:id)
  call_overrides[:tool_name] = overrides.delete(:name) if overrides.key?(:name)
  ctx_overrides[:session_id] = overrides.delete(:session_id) if overrides.key?(:session_id)
  ctx_overrides[:turn] = overrides.delete(:turn) if overrides.key?(:turn)

  Ask::Runtime::Events::ToolStarted.new(
    tool_call: build_tool_call(**call_overrides),
    execution_context: build_execution_context(**ctx_overrides),
    timestamp: Time.now
  )
end

def build_tool_completed_event(**overrides)
  call_overrides = {}
  ctx_overrides = {}
  call_overrides[:id] = overrides.delete(:id) if overrides.key?(:id)
  call_overrides[:tool_name] = overrides.delete(:name) if overrides.key?(:name)
  ctx_overrides[:session_id] = overrides.delete(:session_id) if overrides.key?(:session_id)
  ctx_overrides[:turn] = overrides.delete(:turn) if overrides.key?(:turn)

  Ask::Runtime::Events::ToolCompleted.new(
    tool_call: build_tool_call(**call_overrides),
    tool_result: Ask::Runtime::ToolResult.success(data: "done"),
    execution_context: build_execution_context(**ctx_overrides),
    timestamp: Time.now,
    duration: 1.5
  )
end

def build_tool_failed_event(**overrides)
  call_overrides = {}
  ctx_overrides = {}
  call_overrides[:id] = overrides.delete(:id) if overrides.key?(:id)
  call_overrides[:tool_name] = overrides.delete(:name) if overrides.key?(:name)
  ctx_overrides[:session_id] = overrides.delete(:session_id) if overrides.key?(:session_id)
  ctx_overrides[:turn] = overrides.delete(:turn) if overrides.key?(:turn)

  Ask::Runtime::Events::ToolFailed.new(
    tool_call: build_tool_call(**call_overrides),
    tool_result: Ask::Runtime::ToolResult.failure("file not found"),
    execution_context: build_execution_context(**ctx_overrides),
    timestamp: Time.now,
    duration: 0.5
  )
end

def build_tool_cancelled_event(**overrides)
  call_overrides = {}
  ctx_overrides = {}
  call_overrides[:id] = overrides.delete(:id) if overrides.key?(:id)
  call_overrides[:tool_name] = overrides.delete(:name) if overrides.key?(:name)
  ctx_overrides[:session_id] = overrides.delete(:session_id) if overrides.key?(:session_id)
  ctx_overrides[:turn] = overrides.delete(:turn) if overrides.key?(:turn)

  Ask::Runtime::Events::ToolCancelled.new(
    tool_call: build_tool_call(**call_overrides),
    tool_result: Ask::Runtime::ToolResult.cancelled("Aborted by sibling"),
    execution_context: build_execution_context(**ctx_overrides),
    timestamp: Time.now,
    duration: 0.3
  )
end

def build_tool_timed_out_event(**overrides)
  call_overrides = {}
  ctx_overrides = {}
  call_overrides[:id] = overrides.delete(:id) if overrides.key?(:id)
  call_overrides[:tool_name] = overrides.delete(:name) if overrides.key?(:name)
  ctx_overrides[:session_id] = overrides.delete(:session_id) if overrides.key?(:session_id)
  ctx_overrides[:turn] = overrides.delete(:turn) if overrides.key?(:turn)

  Ask::Runtime::Events::ToolTimedOut.new(
    tool_call: build_tool_call(**call_overrides),
    tool_result: Ask::Runtime::ToolResult.timeout("Execution timed out"),
    execution_context: build_execution_context(**ctx_overrides),
    timestamp: Time.now,
    duration: 30.0
  )
end

def build_terminal_event(type, id: "tc_1")
  case type
  when :tool_completed
    build_tool_completed_event(id: id)
  when :tool_failed
    build_tool_failed_event(id: id)
  when :tool_cancelled
    build_tool_cancelled_event(id: id)
  when :tool_timed_out
    build_tool_timed_out_event(id: id)
  end
end

def capture_stderr
  original = $stderr
  $stderr = StringIO.new
  yield
  $stderr.string
ensure
  $stderr = original
end
