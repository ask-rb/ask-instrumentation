# frozen_string_literal: true

require_relative "../../test_helper"
require "ask/instrumentation"

class InstrumentationChatTest < Minitest::Test
  def setup
    @events = []
    @subscriber = Ask::Instrumentation.subscribe { |e| @events << e }
  end

  def teardown
    Ask::Instrumentation.unsubscribe(@subscriber)
  end

  def test_chat_module_exists
    assert Ask::Instrumentation::Chat
  end

  def test_chat_instrumentation
    Ask::Instrumentation.instrument("chat.ask", provider: "openai", model: "gpt-4") { "response" }
    assert @events.any?
    event = @events.find { |e| e.name == "chat.ask" }
    assert_equal "openai", event.payload[:provider]
    assert_equal "gpt-4", event.payload[:model]
  end

  def test_chat_with_tokens
    Ask::Instrumentation.instrument("chat.ask", provider: "openai", input_tokens: 150, output_tokens: 50) { "done" }
    event = @events.find { |e| e.name == "chat.ask" }
    assert_equal 150, event.payload[:input_tokens]
    assert_equal 50, event.payload[:output_tokens]
  end
end
