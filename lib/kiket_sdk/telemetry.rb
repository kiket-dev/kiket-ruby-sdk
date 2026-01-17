# frozen_string_literal: true

require 'faraday'
require 'time'

class KiketSDK
  ##
  # Telemetry reporter for SDK usage metrics.
  class Telemetry
    def initialize(enabled, telemetry_url, feedback_hook, extension_id, extension_version)
      opt_out = ENV.fetch('KIKET_SDK_TELEMETRY_OPTOUT', nil) == '1'
      @enabled = enabled && !opt_out
      @feedback_hook = feedback_hook
      @extension_id = extension_id
      @extension_version = extension_version
      @telemetry_endpoint = telemetry_url && build_endpoint(telemetry_url)

      @conn = if telemetry_url
                Faraday.new do |f|
                  f.request :json
                  f.response :json
                  f.adapter Faraday.default_adapter
                end
      end
    end

    def record(event, version, status, duration_ms, message = nil, error_class: nil, metadata: {})
      return unless @enabled

      record_data = {
        event: event,
        version: version,
        status: status,
        duration_ms: duration_ms,
        error_message: message,
        error_class: error_class,
        extension_id: @extension_id,
        extension_version: @extension_version,
        timestamp: Time.now.iso8601,
        metadata: metadata || {}
      }

      # Call feedback hook
      if @feedback_hook
        begin
          @feedback_hook.call(record_data)
        rescue StandardError => e
          warn "Feedback hook failed: #{e.message}"
        end
      end

      # Send to telemetry URL
      return unless @conn && @telemetry_endpoint

      begin
        @conn.post(@telemetry_endpoint, record_data)
      rescue StandardError => e
        warn "Failed to send telemetry: #{e.message}"
      end
    end

    private

    def build_endpoint(url)
      trimmed = url.sub(%r{/+$}, '')
      return trimmed if trimmed.end_with?('/telemetry')

      "#{trimmed}/telemetry"
    end
  end
end
