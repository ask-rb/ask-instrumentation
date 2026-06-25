## [0.2.1] - 2026-06-25

### Changed
- Submodule tests: Chat(3t), Embedding(2t), Tool(7t). Infrastructure: rubocop, overcommit, CI matrix, gemspec, SimpleCov.
# Changelog

## 0.2.0 (2026-06-21)

- Fleshed out `Ask::Instrumentation::Tool` module with `instrument` helper
- Emits `tool_call.ask` and `tool_result.ask` events via ActiveSupport::Notifications
- Added structured trace logging to `log/tools/trace.jsonl`

## 0.1.0

- Initial release
