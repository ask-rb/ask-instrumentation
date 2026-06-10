# ask-instrumentation

[![Gem Version](https://badge.fury.io/rb/ask-instrumentation.svg)](https://badge.fury.io/rb/ask-instrumentation)
[![CI](https://github.com/ask-rb/ask-instrumentation/actions/workflows/ci.yml/badge.svg)](https://github.com/ask-rb/ask-instrumentation/actions/workflows/ci.yml)

LLM observability for the ask-rb ecosystem. Emits `ActiveSupport::Notifications`
events for chat completions, embeddings, tool calls, and image generation.

Works with **any** LLM provider — not tied to a specific one. Subscribe to events
for cost tracking, logging, analytics, or alerting.

## Installation

```ruby
gem "ask-instrumentation"
```

Or install it yourself:

```bash
gem install ask-instrumentation
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
| `chat.stream.ask` | provider, model, input_tokens, output_tokens, duration | Streaming chat |
| `tool.ask` | provider, tool_name, tool_args, duration | Tool call |
| `embedding.ask` | provider, model, input_tokens, duration | Embedding |
| `image.ask` | provider, model, size, duration | Image generation |

## Examples

### Cost Tracking

Subscribe to chat events and sum model costs:

```ruby
require "ask/instrumentation"

COST_PER_TOKEN = {
  "gpt-4"        => { input: 0.03 / 1000, output: 0.06 / 1000 },
  "gpt-3.5-turbo" => { input: 0.001 / 1000, output: 0.002 / 1000 },
  "claude-3-opus" => { input: 0.015 / 1000, output: 0.075 / 1000 }
}.freeze

total_cost = 0.0

Ask::Instrumentation.subscribe(/chat\.ask/) do |event|
  payload = event.payload
  model   = payload[:model]
  pricing = COST_PER_TOKEN[model]
  next unless pricing

  cost = (payload[:input_tokens].to_i * pricing[:input]) +
         (payload[:output_tokens].to_i * pricing[:output])
  total_cost += cost

  puts "[COST] #{model}: $%.6f (total: $%.4f)" % [cost, total_cost]
end

# Later, in your application code:
Ask::Instrumentation.with_metadata(session_id: "sess_123") do
  Ask::Instrumentation.instrument("chat.ask",
    provider: "openai",
    model: "gpt-4",
    input_tokens: 150,
    output_tokens: 50
  ) do
    # actual LLM API call
  end
end
```

### Request Logging

Log all LLM events to a file with structured data:

```ruby
require "ask/instrumentation"
require "logger"

logger = Logger.new("log/llm.log")

Ask::Instrumentation.subscribe do |event|
  logger.info({
    event:    event.name,
    duration: event.duration.round(2),
    **event.payload
  }.to_json)
end
```

### Usage Analytics with Metadata

Track per-user and per-session usage:

```ruby
require "ask/instrumentation"

# In your application (e.g., a Rails controller):
class ChatController < ApplicationController
  def create
    Ask::Instrumentation.with_metadata(
      user_id:    current_user.id,
      session_id: request.session.id,
      request_id: request.request_id
    ) do
      # All events emitted here automatically include user/session context
      response = llm_client.chat(params[:message])
      render json: response
    end
  end
end

# In a monitoring background worker:
Ask::Instrumentation.subscribe(/chat\.ask/) do |event|
  payload = event.payload
  UsageReport.increment(
    user_id:    payload[:user_id],
    model:      payload[:model],
    tokens_in:  payload[:input_tokens],
    tokens_out: payload[:output_tokens]
  )
end
```

### Integration with ask-llm-providers

When using the ask-rb ecosystem, providers emit events automatically:

```ruby
require "ask/provider"

# Events are emitted automatically — no manual instrumentation needed.
provider = Ask::Provider.for(:openai)
provider.complete(prompt: "Hello!") # emits chat.ask

# Subscribe to track everything:
Ask::Instrumentation.subscribe do |event|
  puts "[#{event.name}] #{event.payload[:model]} (#{event.duration}ms)"
end
```

### With Your Own Provider

You can emit events from any custom provider:

```ruby
class MyCustomProvider
  def complete(prompt)
    Ask::Instrumentation.instrument("chat.ask",
      provider: "my_custom",
      model: "my-model-v1",
      input_tokens: prompt.length / 4
    ) do
      response = call_api(prompt)
      # enrich payload after the call by returning a hash from the block?
      # No — use with_metadata or include everything upfront.
      response
    end
  end
end
```

## API

### `.subscribe(pattern = /\.ask$/, &block)`

Subscribe to ask events. Accepts an optional pattern (defaults to all `.ask` events).

```ruby
# All ask events
Ask::Instrumentation.subscribe { |event| ... }

# Only chat events
Ask::Instrumentation.subscribe(/chat\.ask/) { |event| ... }
```

### `.unsubscribe(subscriber_or_name)`

Remove a subscriber by passing the object returned from `subscribe` or a string/regexp.

```ruby
subscriber = Ask::Instrumentation.subscribe { |e| ... }
Ask::Instrumentation.unsubscribe(subscriber)
```

### `.instrument(name, payload = {}, &block)`

Emit an event. The block is instrumented and its return value is passed through.
Metadata from `with_metadata` is automatically merged into the payload.

```ruby
result = Ask::Instrumentation.instrument("chat.ask",
  provider: "openai",
  model: "gpt-4"
) do
  llm_call
end
```

### `.with_metadata(hash, &block)`

Set thread-local metadata that is merged into all events emitted inside the block.
Nested blocks merge inner metadata into outer, with inner values taking precedence.

```ruby
Ask::Instrumentation.with_metadata(user_id: 42) do
  Ask::Instrumentation.instrument("chat.ask", provider: "openai", model: "gpt-4") do
    # event payload includes user_id: 42
  end
end
```

### `.current_metadata`

Return the current thread's metadata hash (empty hash if no metadata is set).

```ruby
Ask::Instrumentation.current_metadata # => {}
```

## Thread Safety

All metadata is stored in `Thread.current`, making it safe to use in concurrent
environments. Each thread has its own metadata context:

```ruby
Ask::Instrumentation.with_metadata(thread: "main") do
  Thread.new do
    # This thread has its own metadata context
    Ask::Instrumentation.current_metadata # => {}
    Ask::Instrumentation.with_metadata(thread: "worker") do
      # ...
    end
  end.join
end
```

## Development

```bash
git clone https://github.com/ask-rb/ask-instrumentation.git
cd ask-instrumentation
bundle install
bundle exec rake test
```

## License

MIT
