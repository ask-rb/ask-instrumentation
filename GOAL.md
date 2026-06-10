# ask-instrumentation — LLM Observability for ask-rb

## Purpose

A thin instrumentation layer that emits `ActiveSupport::Notifications` events for
LLM operations (chat completions, embeddings, tool calls, image generation).
Works with ANY LLM provider — events are provider-agnostic.

This is the foundational observability gem. `ask-opentelemetry`, `ask-monitoring`,
and any third-party monitoring tools consume these events.

## Dependencies

- **Runtime:** `activesupport >= 7.0` (for ActiveSupport::Notifications)
- **Build/test:** minitest, mocha, rake
- **No ask-rb dependencies.** This gem can be used standalone by any Ruby app
  that wants event-based LLM observability.

## How This Improves on ruby_llm-instrumentation

| Old Gem | Our Gem |
|---|---|
| Tied to ruby_llm (depends on RubyLLM::Chat, Embedding, etc.) | Provider-agnostic — works with any ask-rb provider or custom one |
| Namespace: `ruby_llm.*` events | Namespace: `ask.*` events |
| Includes/patches ruby_llm classes | Subscribe/unsubscribe API, no monkey-patching |
| Depends on full Rails (railtie, tasks) | Depends only on `activesupport` (lighter) |
| No metadata context helper | `with_metadata` for user/session/trace context |

## Implementation Steps

### 1. Define the core module (`lib/ask/instrumentation.rb`)

The module must provide:

```ruby
Ask::Instrumentation.subscribe(pattern, &block)     # Subscribe to events
Ask::Instrumentation.unsubscribe(subscriber_or_name) # Unsubscribe
Ask::Instrumentation.instrument(name, payload) { }  # Emit event (wraps AS::N.instrument)
Ask::Instrumentation.with_metadata(hash) { }        # Thread-safe metadata context
Ask::Instrumentation.current_metadata               # Current thread's metadata
```

Implementation notes:
- `subscribe` delegates to `ActiveSupport::Notifications.subscribe`
- `instrument` delegates to `ActiveSupport::Notifications.instrument`
- `with_metadata` stores metadata in `Thread.current[:ask_instrumentation_metadata]`
- Metadata is a hash that gets merged into event payloads
- Events must include both the explicit payload AND the thread metadata

### 2. Define event conventions

Event names follow `{operation}.ask` pattern:

```
chat.ask        # Chat completion
chat.stream.ask # Streaming chat
tool.ask        # Tool execution
embedding.ask   # Embedding generation
image.ask       # Image generation
```

Each event payload includes `duration` (automatically by AS::N) and:
- `provider` — the LLM provider name
- `model` — the model identifier
- Provider-specific metrics (input_tokens, output_tokens, etc.)

### 3. Write tests

- Test subscribe with pattern matching
- Test instrument emits events with correct payload
- Test with_metadata context isolation (thread-safe)
- Test unsubscribe removes subscription
- Test nested with_metadata blocks (merge behavior)

### 4. Document

Every method must have YARDoc. The README should show:
- Basic subscription
- Cost tracking example (subscribe to chat.ask, sum costs)
- Logging example (subscribe to all events, log to file)
- Integration with ask-llm-providers

## Release Notes

- v0.1.0: Core module + event conventions + tests
- v0.2.0: Rails railtie for auto-loading
- v0.3.0: Additional event types (moderation, transcription)

See the v0.1.0 Completion Checklist in the master GOAL file for release criteria.
