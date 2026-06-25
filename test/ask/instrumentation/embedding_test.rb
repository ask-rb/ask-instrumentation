# frozen_string_literal: true

require_relative "../../test_helper"
require "ask/instrumentation"

class InstrumentationEmbeddingTest < Minitest::Test
  def setup
    @events = []
    @subscriber = Ask::Instrumentation.subscribe { |e| @events << e }
  end

  def teardown
    Ask::Instrumentation.unsubscribe(@subscriber)
  end

  def test_embedding_module_exists
    assert Ask::Instrumentation::Embedding
  end

  def test_embedding_instrumentation
    Ask::Instrumentation.instrument("embedding.ask", provider: "openai", model: "text-embedding-3") { [0.1, 0.2] }
    assert @events.any?
    event = @events.find { |e| e.name == "embedding.ask" }
    assert_equal "openai", event.payload[:provider]
    assert_equal "text-embedding-3", event.payload[:model]
  end
end
