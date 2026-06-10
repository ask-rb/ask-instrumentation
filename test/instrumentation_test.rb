require_relative "test_helper"
require "ask/instrumentation"

class InstrumentationTest < Minitest::Test
  def setup
    @events = []
    @subscriber = Ask::Instrumentation.subscribe do |event|
      @events << event
    end
  end

  def teardown
    Ask::Instrumentation.unsubscribe(@subscriber)
  end

  # --- subscribe ---

  def test_subscribe_with_default_pattern_catches_all_ask_events
    Ask::Instrumentation.instrument("chat.ask", provider: "openai")
    Ask::Instrumentation.instrument("embedding.ask", provider: "openai")

    assert_equal 2, @events.size
    assert_equal %w[chat.ask embedding.ask], @events.map(&:name)
  end

  def test_subscribe_with_custom_pattern
    chat_events = []
    sub = Ask::Instrumentation.subscribe(/chat\.ask/) { |e| chat_events << e }

    Ask::Instrumentation.instrument("chat.ask", provider: "openai")
    Ask::Instrumentation.instrument("embedding.ask", provider: "openai")

    assert_equal 1, chat_events.size
    assert_equal "chat.ask", chat_events.first.name

    Ask::Instrumentation.unsubscribe(sub)
  end

  def test_subscribe_with_string_pattern
    events = []
    sub = Ask::Instrumentation.subscribe("chat.ask") { |e| events << e }

    Ask::Instrumentation.instrument("chat.ask", provider: "openai")
    Ask::Instrumentation.instrument("embedding.ask", provider: "openai")

    assert_equal 1, events.size

    Ask::Instrumentation.unsubscribe(sub)
  end

  # --- unsubscribe ---

  def test_unsubscribe_removes_subscriber
    Ask::Instrumentation.unsubscribe(@subscriber)
    @events.clear

    Ask::Instrumentation.instrument("chat.ask", provider: "openai")

    assert @events.empty?
  end

  def test_unsubscribe_isolated_subscriber
    isolated = []
    sub = Ask::Instrumentation.subscribe(/chat\.ask/) { |e| isolated << e }
    Ask::Instrumentation.unsubscribe(sub)

    Ask::Instrumentation.instrument("chat.ask", provider: "openai")

    assert isolated.empty?
  end

  # --- instrument ---

  def test_instrument_emits_event_with_correct_name
    Ask::Instrumentation.instrument("chat.ask", provider: "openai")

    assert_equal 1, @events.size
    assert_equal "chat.ask", @events.first.name
  end

  def test_instrument_emits_event_with_payload
    Ask::Instrumentation.instrument("chat.ask",
      provider: "openai",
      model: "gpt-4",
      input_tokens: 150,
      output_tokens: 50
    )

    event = @events.first
    assert_equal "openai", event.payload[:provider]
    assert_equal "gpt-4", event.payload[:model]
    assert_equal 150, event.payload[:input_tokens]
    assert_equal 50, event.payload[:output_tokens]
  end

  def test_instrument_includes_duration
    Ask::Instrumentation.instrument("chat.ask", provider: "openai") do
      sleep 0.01
    end

    event = @events.first
    assert event.duration > 0, "Expected duration to be positive"
  end

  def test_instrument_yields_block_and_returns_value
    result = Ask::Instrumentation.instrument("chat.ask", provider: "openai") do
      "hello"
    end

    assert_equal "hello", result
  end

  def test_instrument_without_block_still_emits_event
    Ask::Instrumentation.instrument("chat.ask", provider: "openai")

    assert_equal 1, @events.size
  end

  # --- with_metadata ---

  def test_with_metadata_merged_into_event_payload
    Ask::Instrumentation.with_metadata(user_id: 42, session_id: "abc") do
      Ask::Instrumentation.instrument("chat.ask", provider: "openai")
    end

    event = @events.first
    assert_equal 42, event.payload[:user_id]
    assert_equal "abc", event.payload[:session_id]
    assert_equal "openai", event.payload[:provider]
  end

  def test_with_metadata_restored_after_block
    Ask::Instrumentation.with_metadata(user_id: 42) do
      Ask::Instrumentation.instrument("chat.ask", provider: "openai")
    end

    # After block: metadata should be empty
    Ask::Instrumentation.instrument("chat.ask", provider: "openai")

    event = @events.last
    assert_nil event.payload[:user_id], "metadata should not leak after block"
  end

  def test_nested_with_metadata_merges
    Ask::Instrumentation.with_metadata(user_id: 42) do
      Ask::Instrumentation.with_metadata(session_id: "abc") do
        Ask::Instrumentation.instrument("chat.ask", provider: "openai")
      end
    end

    event = @events.first
    assert_equal 42, event.payload[:user_id]
    assert_equal "abc", event.payload[:session_id]
  end

  def test_nested_with_metadata_inner_overrides_outer
    Ask::Instrumentation.with_metadata(user_id: 42, role: "admin") do
      Ask::Instrumentation.with_metadata(role: "user") do
        Ask::Instrumentation.instrument("chat.ask", provider: "openai")
      end
    end

    event = @events.first
    assert_equal 42, event.payload[:user_id]
    assert_equal "user", event.payload[:role]
  end

  def test_nested_with_metadata_restores_outer_after_inner_block
    Ask::Instrumentation.with_metadata(role: "admin") do
      Ask::Instrumentation.with_metadata(role: "user") do
      end
      Ask::Instrumentation.instrument("chat.ask", provider: "openai")
    end

    event = @events.first
    assert_equal "admin", event.payload[:role]
  end

  def test_metadata_is_thread_safe
    outer_events = []
    inner_events = []

    outer_sub = Ask::Instrumentation.subscribe(/outer\.ask/) { |e| outer_events << e }
    inner_sub = Ask::Instrumentation.subscribe(/inner\.ask/) { |e| inner_events << e }

    Ask::Instrumentation.with_metadata(thread: "main") do
      Ask::Instrumentation.instrument("outer.ask", provider: "openai")

      Thread.new do
        Ask::Instrumentation.with_metadata(thread: "background") do
          Ask::Instrumentation.instrument("inner.ask", provider: "openai")
        end
      end.join

      Ask::Instrumentation.instrument("outer.ask", provider: "openai")
    end

    assert_equal "background", inner_events.first.payload[:thread]
    assert_equal %w[main main], outer_events.map { |e| e.payload[:thread] }

    Ask::Instrumentation.unsubscribe(outer_sub)
    Ask::Instrumentation.unsubscribe(inner_sub)
  end

  # --- current_metadata ---

  def test_current_metadata_returns_empty_hash_when_not_set
    assert_equal({}, Ask::Instrumentation.current_metadata)
  end

  def test_current_metadata_returns_current_thread_metadata
    Ask::Instrumentation.with_metadata(user_id: 42) do
      assert_equal({ user_id: 42 }, Ask::Instrumentation.current_metadata)
    end
  end

  def test_current_metadata_empty_after_with_metadata_block
    Ask::Instrumentation.with_metadata(user_id: 42) do
      # inside
    end
    assert_equal({}, Ask::Instrumentation.current_metadata)
  end

  # --- instrument payload precedence ---

  def test_instrument_payload_overrides_metadata
    Ask::Instrumentation.with_metadata(provider: "default_provider") do
      Ask::Instrumentation.instrument("chat.ask", provider: "openai", model: "gpt-4")
    end

    event = @events.first
    assert_equal "openai", event.payload[:provider]
  end
end
