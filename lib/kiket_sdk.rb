# frozen_string_literal: true

require 'sinatra/base'
require 'json'
require 'yaml'

##
# Main SDK class for building Kiket extensions.
class KiketSDK < Sinatra::Base
  ##
  # Error raised when required scopes are not present.
  class ScopeError < StandardError
    attr_reader :required_scopes, :available_scopes, :missing_scopes

    def initialize(required_scopes, available_scopes)
      @required_scopes = Array(required_scopes)
      @available_scopes = Array(available_scopes)
      @missing_scopes = @required_scopes - @available_scopes

      super("Insufficient scopes: missing #{@missing_scopes.join(', ')}")
    end
  end
end

require_relative 'kiket_sdk/version'
require_relative 'kiket_sdk/auth'
require_relative 'kiket_sdk/client'
require_relative 'kiket_sdk/config'
require_relative 'kiket_sdk/endpoints'
require_relative 'kiket_sdk/custom_data'
require_relative 'kiket_sdk/sla_events'
require_relative 'kiket_sdk/manifest'
require_relative 'kiket_sdk/registry'
require_relative 'kiket_sdk/secrets'
require_relative 'kiket_sdk/telemetry'
require_relative 'kiket/notifications'

# Reopen class to add methods
class KiketSDK
  def initialize(config = {})
    @manifest = KiketSDK::Manifest.load(config[:manifest_path])
    @config = resolve_config(config, @manifest)
    @registry = KiketSDK::Registry.new
    @telemetry = KiketSDK::Telemetry.new(
      @config[:telemetry_enabled],
      @config[:telemetry_url],
      @config[:feedback_hook],
      @config[:extension_id],
      @config[:extension_version]
    )

    super()
  end

  # Routes must be defined at class level in Sinatra
  post '/webhooks/:event' do
    dispatch_webhook(params[:event], nil)
  end

  post '/v/:version/webhooks/:event' do
    dispatch_webhook(params[:event], params[:version])
  end

  get '/health' do
    content_type :json
    {
      status: 'ok',
      extension_id: @config&.dig(:extension_id),
      extension_version: @config&.dig(:extension_version),
      registered_events: @registry&.event_names || []
    }.to_json
  end

  ##
  # Register a webhook handler.
  # @param event [String] Event name
  # @param version [String] Event version
  # @param required_scopes [Array<String>] Scopes required to execute this handler
  def register(event, version:, required_scopes: [], &handler)
    @registry.register(event, version, handler, required_scopes: required_scopes)
  end

  ##
  # Webhook decorator for registering handlers.
  # @param event [String] Event name
  # @param version [String] Event version
  # @param required_scopes [Array<String>] Scopes required to execute this handler
  def webhook(event, version:, required_scopes: [])
    lambda do |&handler|
      register(event, version: version, required_scopes: required_scopes, &handler)
      handler
    end
  end

  ##
  # Start the Sinatra server.
  def run!(host: '127.0.0.1', port: 8000)
    puts "🚀 Kiket extension listening on http://#{host}:#{port}"
    puts "📦 Extension: #{@config[:extension_id] || 'unknown'}"
    puts "📝 Registered events: #{@registry.event_names.join(', ')}"

    Rack::Handler::Puma.run(
      self,
      Host: host,
      Port: port,
      Threads: '0:16'
    )
  end

  private

  def dispatch_webhook(event, path_version)
    body = request.body.read
    request.body.rewind

    # Parse payload first
    payload = JSON.parse(body)

    # Resolve API base URL from payload or config
    api_base_url = payload.dig('api', 'base_url') || @config[:base_url]

    # Verify JWT runtime token
    begin
      jwt_payload = KiketSDK::Auth.verify_runtime_token(payload, api_base_url)
    rescue KiketSDK::Auth::AuthenticationError => e
      halt 401, { error: e.message }.to_json
    end

    # Determine version
    requested_version = path_version ||
                        request.env['HTTP_X_KIKET_EVENT_VERSION'] ||
                        params['version']

    halt 400, { error: 'Event version required' }.to_json if requested_version.nil? || requested_version.empty?

    # Get handler
    metadata = @registry.get(event, requested_version)
    if metadata.nil?
      halt 404, { error: "No handler registered for event '#{event}' with version '#{requested_version}'" }.to_json
    end

    # Build authentication context from verified JWT and payload
    auth_context = build_auth_context(jwt_payload, payload)

    # Check required scopes before proceeding
    required_scopes = metadata[:required_scopes] || []
    unless required_scopes.empty?
      missing = check_scopes(required_scopes, auth_context[:scopes])
      unless missing.empty?
        halt 403, { content_type: :json }, {
          error: 'Insufficient scopes',
          required_scopes: required_scopes,
          missing_scopes: missing
        }.to_json
      end
    end

    # Create client with runtime token
    client = KiketSDK::Client.new(
      api_base_url,
      @config[:workspace_token],
      metadata[:version],
      runtime_token: auth_context[:runtime_token]
    )

    endpoints = KiketSDK::Endpoints.new(client, @config[:extension_id], metadata[:version])

    # Build scope checking utility for context
    scope_checker = build_scope_checker(auth_context[:scopes])

    # Extract payload secrets for quick access (bundled by SecretResolver)
    payload_secrets = payload['secrets'] || {}

    # Build secret helper: checks payload secrets first (per-org), falls back to ENV (extension defaults)
    secret_helper = build_secret_helper(payload_secrets)

    context = {
      event: event,
      event_version: metadata[:version],
      headers: extract_headers(request.env),
      client: client,
      endpoints: endpoints,
      settings: @config[:settings],
      extension_id: @config[:extension_id],
      extension_version: @config[:extension_version],
      secrets: endpoints.secrets,
      secret: secret_helper,
      payload_secrets: payload_secrets,
      auth: auth_context,
      require_scopes: scope_checker
    }

    # Execute handler with telemetry
    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    begin
      result = metadata[:handler].call(payload, context)
      duration_ms = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000

      @telemetry.record(event, metadata[:version], 'ok', duration_ms)

      content_type :json
      (result || { ok: true }).to_json
    rescue StandardError => e
      duration_ms = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000
      @telemetry.record(event, metadata[:version], 'error', duration_ms, e.message, error_class: e.class.name)

      halt 500, { error: e.message }.to_json
    end
  end

  def resolve_config(config, manifest)
    base_url = config[:base_url] || ENV.fetch('KIKET_BASE_URL', 'https://kiket.dev')
    workspace_token = config[:workspace_token] || ENV.fetch('KIKET_WORKSPACE_TOKEN', nil)

    settings = {}
    if manifest
      settings.merge!(manifest.settings_defaults)
      settings.merge!(manifest.apply_secret_env_overrides) if config.fetch(:auto_env_secrets, true)
    end
    settings.merge!(config[:settings]) if config[:settings]

    extension_id = config[:extension_id] || manifest&.id
    extension_version = config[:extension_version] || manifest&.version
    telemetry_url = config[:telemetry_url] ||
                    ENV.fetch('KIKET_SDK_TELEMETRY_URL', nil) ||
                    "#{base_url.sub(%r{/+$}, '')}/api/v1/ext"

    {
      workspace_token: workspace_token,
      base_url: base_url,
      settings: settings,
      extension_id: extension_id,
      extension_version: extension_version,
      telemetry_enabled: config.fetch(:telemetry_enabled, true),
      feedback_hook: config[:feedback_hook],
      telemetry_url: telemetry_url
    }
  end

  def extract_headers(env)
    env.select { |k, _| k.start_with?('HTTP_') }
       .transform_keys { |k| k.sub(/^HTTP_/, '').tr('_', '-').downcase }
  end

  ##
  # Build authentication context from verified JWT payload and raw payload.
  # @param jwt_payload [Hash] The verified JWT claims
  # @param raw_payload [Hash] The original webhook payload
  def build_auth_context(jwt_payload, raw_payload)
    raw_auth = raw_payload.is_a?(Hash) ? (raw_payload['authentication'] || {}) : {}

    {
      runtime_token: raw_auth['runtime_token'],
      token_type: 'runtime',
      expires_at: jwt_payload['exp'] ? Time.at(jwt_payload['exp']).iso8601 : nil,
      scopes: jwt_payload['scopes'] || [],
      org_id: jwt_payload['org_id'],
      ext_id: jwt_payload['ext_id'],
      proj_id: jwt_payload['proj_id']
    }
  end

  ##
  # Check if all required scopes are present.
  # @return [Array<String>] List of missing scopes (empty if all present)
  def check_scopes(required_scopes, available_scopes)
    required = Array(required_scopes)
    available = Array(available_scopes)

    # Wildcard scope grants all permissions
    return [] if available.include?('*')

    required - available
  end

  ##
  # Build a scope checker lambda for use in handler context.
  def build_scope_checker(available_scopes)
    lambda do |*required_scopes|
      required = required_scopes.flatten
      missing = check_scopes(required, available_scopes)
      raise ScopeError.new(required, available_scopes) unless missing.empty?

      true
    end
  end

  ##
  # Build a secret helper lambda for use in handler context.
  # Checks payload secrets first (per-org configuration bundled by SecretResolver),
  # then falls back to environment variables (extension defaults).
  #
  # @param payload_secrets [Hash] Secrets from payload['secrets']
  # @return [Proc] Lambda that resolves secrets by key
  #
  # @example
  #   # In handler:
  #   slack_token = context[:secret].call('SLACK_BOT_TOKEN')
  #   # Returns payload["secrets"]["SLACK_BOT_TOKEN"] || ENV["SLACK_BOT_TOKEN"]
  def build_secret_helper(payload_secrets)
    lambda do |key|
      # Payload secrets (per-org) take priority over ENV (extension defaults)
      payload_secrets[key] || payload_secrets[key.to_s] || ENV[key.to_s]
    end
  end
end
