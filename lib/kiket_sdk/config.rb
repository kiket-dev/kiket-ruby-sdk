# frozen_string_literal: true

class KiketSDK
  ##
  # SDK configuration.
  class Config
    attr_reader :webhook_secret, :workspace_token, :extension_api_key, :base_url, :settings,
                :extension_id, :extension_version, :telemetry_enabled,
                :feedback_hook, :telemetry_url

    def initialize(options = {})
      @webhook_secret = options[:webhook_secret]
      @workspace_token = options[:workspace_token]
      @extension_api_key = options[:extension_api_key]
      @base_url = options[:base_url] || 'https://kiket.dev'
      @settings = options[:settings] || {}
      @extension_id = options[:extension_id]
      @extension_version = options[:extension_version]
      @telemetry_enabled = options.fetch(:telemetry_enabled, true)
      @feedback_hook = options[:feedback_hook]
      @telemetry_url = options[:telemetry_url]
    end
  end
end
