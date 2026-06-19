# frozen_string_literal: true

require "json"
require "fileutils"

module Ask
  module Instrumentation
    module Tool
      TRACE_LOG_DIR = File.expand_path("log/tools", Dir.pwd)

      class << self
        def instrument(name:, arguments:, tool_call_id:, metadata: {}, &block)
          arg_size = arguments.to_s.length
          payload = {
            name: name,
            arguments: arguments,
            argument_size: arg_size,
            tool_call_id: tool_call_id
          }.merge(metadata)

          Ask::Instrumentation.instrument("tool_call.ask", payload)

          start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          begin
            result = block.call
            duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round(1)
            result_size = result.to_s.length

            result_payload = {
              name: name,
              duration_ms: duration_ms,
              result_size: result_size,
              success: true,
              tool_call_id: tool_call_id
            }.merge(metadata)

            Ask::Instrumentation.instrument("tool_result.ask", result_payload)
            write_trace_log(name: name, duration_ms: duration_ms, success: true,
                           argument_size: arg_size, result_size: result_size,
                           tool_call_id: tool_call_id)
            result
          rescue => e
            duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round(1)

            error_payload = {
              name: name,
              duration_ms: duration_ms,
              error: e.class.name,
              error_message: e.message,
              success: false,
              tool_call_id: tool_call_id
            }.merge(metadata)

            Ask::Instrumentation.instrument("tool_result.ask", error_payload)
            write_trace_log(name: name, duration_ms: duration_ms, success: false,
                           error: "#{e.class.name}: #{e.message}",
                           tool_call_id: tool_call_id)
            raise
          end
        end

        def write_trace_log(**payload)
          entry = payload.merge(timestamp: Time.now.utc.iso8601(3))
          dir = TRACE_LOG_DIR
          FileUtils.mkdir_p(dir)
          File.open(File.join(dir, "trace.jsonl"), "a") do |f|
            f.puts(JSON.generate(entry))
          end
        rescue => e
          $stderr.puts "[ask-instrumentation] Failed to write trace log: #{e.message}"
        end
      end
    end
  end
end
