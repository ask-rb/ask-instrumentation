# ask-instrumentation

[![Gem Version](https://badge.fury.io/rb/ask-instrumentation.svg)](https://badge.fury.io/rb/ask-instrumentation)
[![CI](https://github.com/ask-rb/ask-instrumentation/actions/workflows/ci.yml/badge.svg)](https://github.com/ask-rb/ask-instrumentation/actions/workflows/ci.yml)

LLM observability for the ask-rb ecosystem. Wraps `ActiveSupport::Notifications`
and emits events for chat completions, embeddings, tool calls, and image
generation. Works with any LLM provider: subscribe to events for cost
tracking, logging, analytics, or alerting.

## Installation

```ruby
gem "ask-instrumentation"
```

## Quick Start

```ruby
require "ask/instrumentation"

# Subscribe to all ask events
Ask::Instrumentation.subscribe do |event|
  puts "#{event.name}: #{event.duration}ms"
end

# Instrument a block of work
Ask::Instrumentation.instrument("chat.ask", provider: "openai", model: "gpt-4") do
  # your LLM call here
end

# Attach context to every event emitted inside the block
Ask::Instrumentation.with_metadata(user_id: 42, session_id: "abc") do
  Ask::Instrumentation.instrument("chat.ask", provider: "openai", model: "gpt-4") do
    # ...
  end
end
```

## Events

| Event | Description |
|---|---|
| `chat.ask` | Chat completion |
| `chat.stream.ask` | Streaming chat |
| `tool.ask` | Tool execution |
| `embedding.ask` | Embedding generation |
| `image.ask` | Image generation |
| `tool_call.ask` | LLM requested a tool call |
| `tool_result.ask` | Tool call result (or error) |

Event payloads carry provider, model, and token counts when available, plus
any metadata set with `with_metadata`.

## Essential API

| Entry point | Purpose |
|---|---|
| `Ask::Instrumentation.subscribe(pattern = /\.ask$/, &block)` | Subscribe to matching events; returns a subscriber for `unsubscribe` |
| `Ask::Instrumentation.unsubscribe(subscriber_or_pattern)` | Remove a subscriber |
| `Ask::Instrumentation.instrument(name, payload = {}) { }` | Emit an event, timing the block and passing through its return value |
| `Ask::Instrumentation.with_metadata(hash) { }` | Thread-local metadata merged into all events emitted inside the block |
| `Ask::Instrumentation.current_metadata` | Current thread's metadata hash |

Metadata lives in `Thread.current`, so concurrent threads each carry their own
context. Nested `with_metadata` calls merge, with inner values taking
precedence.

## Full documentation

The full ask-rb documentation lives at https://ask-rb.github.io/ask-docs.
https://ask-rb.github.io/ask-docs/production/observability covers
ask-instrumentation in depth. API reference:
https://ask-rb.github.io/ask-docs/reference/api.

## Development

bundle install
bundle exec rake test

## License

MIT
