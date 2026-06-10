require_relative "lib/ask/instrumentation/version"

Gem::Specification.new do |spec|
  spec.name = "ask-instrumentation"
  spec.version = Ask::Instrumentation::VERSION
  spec.authors = ["Kaka Ruto"]
  spec.email = ["kaka@myrrlabs.com"]

  spec.summary = "LLM observability for the ask-rb ecosystem"
  spec.description = "Emits ActiveSupport::Notifications events for chat completions, embeddings, " \
                     "tool calls, and image generation. Works with any LLM provider. " \
                     "Subscribe to events for cost tracking, logging, analytics, or alerting."
  spec.homepage = "https://github.com/ask-rb/ask-instrumentation"
  spec.license = "MIT"

  spec.required_ruby_version = ">= 3.2"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/master/CHANGELOG.md"

  spec.files = Dir["lib/**/*", "LICENSE", "README.md", "CHANGELOG.md"]
  spec.require_paths = ["lib"]

  spec.add_dependency "activesupport", ">= 7.0"

  spec.add_development_dependency "minitest", "~> 5.25"
  spec.add_development_dependency "mocha", "~> 3.1"
  spec.add_development_dependency "rake", "~> 13.0"
end
