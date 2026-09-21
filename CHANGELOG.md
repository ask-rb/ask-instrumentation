## [0.2.1] - 2026-06-25

### Added
- `RuntimeAdapter` — bridges ask-runtime EventSink events to Ask::Instrumentation events with stable names (`tool.started.ask`, `tool.completed.ask`, `tool.failed.ask`, `tool.cancelled.ask`, `tool.timed_out.ask`) and uniform payload schema (tool_call_id, tool_name, session_id, turn, duration, outcome, error, event).
- `Ask::Instrumentation.install_runtime_sink` — one-liner helper to create and return an adapter sink.
- Opt-in, no-op safe, thread-safe. No hard dependency from ask-runtime to ask-instrumentation.

### Changed
- Submodule tests: Chat(3t), Embedding(2t), Tool(7t). Infrastructure: rubocop, overcommit, CI matrix, gemspec, SimpleCov.
# Changelog

## 0.2.0 (2026-06-21)

- Fleshed out `Ask::Instrumentation::Tool` module with `instrument` helper
- Emits `tool_call.ask` and `tool_result.ask` events via ActiveSupport::Notifications
- Added structured trace logging to `log/tools/trace.jsonl`

## 0.1.0

- Initial release
