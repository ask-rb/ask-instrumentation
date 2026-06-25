# frozen_string_literal: true

require_relative "../../test_helper"
require "ask/instrumentation"
require "tmpdir"

class InstrumentationToolTest < Minitest::Test
  def setup
    @events = []
    @subscriber = Ask::Instrumentation.subscribe do |event|
      @events << event
    end
  end

  def teardown
    Ask::Instrumentation.unsubscribe(@subscriber)
  end

  def test_instrument_emits_start_and_result_events
    result = Ask::Instrumentation::Tool.instrument(
      name: "get_weather",
      arguments: { city: "London" },
      tool_call_id: "call_1"
    ) { "sunny" }

    assert_equal "sunny", result
    names = @events.map(&:name)
    assert_includes names, "tool_call.ask"
    assert_includes names, "tool_result.ask"
  end

  def test_instrument_captures_arguments_size
    Ask::Instrumentation::Tool.instrument(
      name: "search",
      arguments: { query: "hello world" },
      tool_call_id: "call_2"
    ) { "results" }

    payload = @events.find { |e| e.name == "tool_call.ask" }.payload
    assert payload[:argument_size] > 0
    assert_equal "search", payload[:name]
  end

  def test_instrument_captures_duration
    Ask::Instrumentation::Tool.instrument(
      name: "slow_tool",
      arguments: {},
      tool_call_id: "call_3"
    ) { sleep 0.01; "done" }

    result_event = @events.find { |e| e.name == "tool_result.ask" }
    assert result_event.payload[:duration_ms] > 0
    assert result_event.payload[:success]
  end

  def test_instrument_handles_errors
    assert_raises(RuntimeError) do
      Ask::Instrumentation::Tool.instrument(
        name: "failing_tool",
        arguments: {},
        tool_call_id: "call_4"
      ) { raise "something broke" }
    end

    result_event = @events.find { |e| e.name == "tool_result.ask" }
    refute result_event.payload[:success]
    assert_equal "RuntimeError", result_event.payload[:error]
  end

  def test_instrument_includes_metadata
    Ask::Instrumentation::Tool.instrument(
      name: "search",
      arguments: { q: "test" },
      tool_call_id: "call_5",
      metadata: { user_id: 42, session_id: "abc" }
    ) { "found" }

    start = @events.find { |e| e.name == "tool_call.ask" }
    assert_equal 42, start.payload[:user_id]
    assert_equal "abc", start.payload[:session_id]
  end

  def test_trace_log_creates_file
    Dir.mktmpdir do |dir|
      old_dir = Ask::Instrumentation::Tool.__send__(:remove_const, :TRACE_LOG_DIR)
      begin
        Ask::Instrumentation::Tool.const_set(:TRACE_LOG_DIR, dir)
        Ask::Instrumentation::Tool.write_trace_log(
          name: "test_tool", duration_ms: 10.0, success: true,
          tool_call_id: "call_6"
        )
        log_files = Dir[File.join(dir, "*.jsonl")]
        assert_equal 1, log_files.size
        content = File.read(log_files.first)
        parsed = JSON.parse(content)
        assert_equal "test_tool", parsed["name"]
      ensure
        Ask::Instrumentation::Tool.__send__(:remove_const, :TRACE_LOG_DIR)
        Ask::Instrumentation::Tool.const_set(:TRACE_LOG_DIR, old_dir)
      end
    end
  end

  def test_write_trace_log_handles_write_errors
    Ask::Instrumentation::Tool.write_trace_log(name: "test")
    assert true
  end
end
