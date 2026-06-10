# ask-instrumentation

[![Gem Version](https://badge.fury.io/rb/ask-instrumentation.svg)](https://badge.fury.io/rb/ask-instrumentation)

LLM observability for the ask-rb ecosystem. Emits `ActiveSupport::Notifications`
events for chat completions, embeddings, tool calls, and more.

Works with **any** LLM provider — not tied to a specific one. Subscribe to events
for cost tracking, logging, analytics, or alerting.

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

# Instrument a chat completion
Ask::Instrumentation.instrument("chat.ask", provider: "openai", model: "gpt-4") do
  # your LLM call here
end

# Wrap with metadata context
Ask::Instrumentation.with_metadata(user_id: 42, session_id: "abc") do
  Ask::Instrumentation.instrument("chat.ask", { provider: "openai", model: "gpt-4" }) do
    # ...
  end
end
```

## Events

| Event | Payload | Description |
|---|---|---|
| `chat.ask` | provider, model, input_tokens, output_tokens, duration | Chat completion |
| `tool.ask` | provider, tool_name, tool_args, duration | Tool call |
| `embedding.ask` | provider, model, input_tokens, duration | Embedding |
| `image.ask` | provider, model, size, duration | Image generation |

## Integration

### With ask-llm-providers

Ask::Provider emits events automatically when you make calls. No setup needed.

### With your own provider

Any provider can emit Ask::Instrumentation events — just call `instrument` in
your provider implementation.

## Development

```bash
git clone https://github.com/ask-rb/ask-instrumentation.git
cd ask-instrumentation
bundle install
bundle exec rake test
```

## License

MIT
