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
| `tool.started.ask` | Runtime tool execution started |
| `tool.completed.ask` | Runtime tool execution completed |
| `tool.failed.ask` | Runtime tool execution failed |
| `tool.cancelled.ask` | Runtime tool execution cancelled |
| `tool.timed_out.ask` | Runtime tool execution timed out |

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

## Runtime Adapter

The `RuntimeAdapter` bridges [ask-runtime](https://github.com/ask-rb/ask-runtime)
tool lifecycle events to Ask::Instrumentation events. This lets you observe
tool execution through the same instrumentation pipeline as LLM calls.

```ruby
require "ask/instrumentation"
require "ask/instrumentation/runtime_adapter"

# One-liner: creates a sink that forwards events to Ask::Instrumentation
sink = Ask::Instrumentation.install_runtime_sink

# Wire into an execution context
ctx = Ask::Runtime::ExecutionContext.new(
  session_id: "s_001", turn: 1, event_sink: sink
)

# Subscribe to the forwarded events
Ask::Instrumentation.subscribe do |event|
  case event.name
  when "tool.started.ask"
    puts "Tool started: #{event.payload[:tool_name]}"
  when "tool.completed.ask"
    puts "Tool #{event.payload[:tool_name]} completed in #{event.payload[:duration]}s"
  when "tool.failed.ask"
    puts "Tool #{event.payload[:tool_name]} failed: #{event.payload[:error]}"
  end
end
```

### Event Mapping

| Runtime EventSink type | Ask::Instrumentation event |
|---|---|
| `:tool_started` | `tool.started.ask` |
| `:tool_completed` | `tool.completed.ask` |
| `:tool_failed` | `tool.failed.ask` |
| `:tool_cancelled` | `tool.cancelled.ask` |
| `:tool_timed_out` | `tool.timed_out.ask` |

### Payload Schema

Every forwarded event includes:

| Key | Type | Description |
|---|---|---|
| `tool_call_id` | String | Unique tool-call identifier |
| `tool_name` | String | The tool being executed |
| `session_id` | String, nil | Session correlation |
| `turn` | Integer, nil | Turn number |
| `duration` | Float, nil | Seconds (nil for `tool.started.ask`) |
| `outcome` | String, nil | `"success"`, `"failure"`, `"cancelled"`, `"timed_out"`, or nil |
| `error` | String, nil | Error message (failures and cancellations) |
| `event` | Object | The original runtime event object |

### Lifecycle

```ruby
adapter = Ask::Instrumentation::RuntimeAdapter.new
sink = adapter.sink        # use this as your EventSink
adapter.subscribed?        # => true
adapter.unsubscribe        # stop forwarding events
adapter.subscribed?        # => false
```

### Dependencies

The adapter requires `ask-runtime` at runtime. If `ask-runtime` is not
available, `install_runtime_sink` returns `Ask::Runtime::EventSink.null`
(a no-op sink). The adapter is fully opt-in and creates no hard dependency
from ask-runtime to ask-instrumentation.

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
