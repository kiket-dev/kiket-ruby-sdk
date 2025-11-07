# frozen_string_literal: true

require "sinatra/base"
require "json"
require "yaml"
require_relative "kiket_sdk/version"
require_relative "kiket_sdk/auth"
require_relative "kiket_sdk/client"
require_relative "kiket_sdk/config"
require_relative "kiket_sdk/endpoints"
require_relative "kiket_sdk/manifest"
require_relative "kiket_sdk/registry"
require_relative "kiket_sdk/secrets"
require_relative "kiket_sdk/telemetry"

##
# Main SDK class for building Kiket extensions.
class KiketSDK < Sinatra::Base
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
    setup_routes
  end

  ##
  # Register a webhook handler.
  def register(event, version:, &handler)
    @registry.register(event, version, handler)
  end

  ##
  # Webhook decorator for registering handlers.
  def webhook(event, version:)
    lambda do |&handler|
      register(event, version: version, &handler)
      handler
    end
  end

  ##
  # Start the Sinatra server.
  def run!(host: "127.0.0.1", port: 8000)
    puts "🚀 Kiket extension listening on http://#{host}:#{port}"
    puts "📦 Extension: #{@config[:extension_id] || "unknown"}"
    puts "📝 Registered events: #{@registry.event_names.join(", ")}"

    Rack::Handler::Puma.run(
      self,
      Host: host,
      Port: port,
      Threads: "0:16"
    )
  end

  private

  def setup_routes
    # Webhook endpoints
    post "/webhooks/:event" do
      dispatch_webhook(params[:event], nil)
    end

    post "/v/:version/webhooks/:event" do
      dispatch_webhook(params[:event], params[:version])
    end

    # Health check
    get "/health" do
      content_type :json
      {
        status: "ok",
        extension_id: @config[:extension_id],
        extension_version: @config[:extension_version],
        registered_events: @registry.event_names
      }.to_json
    end
  end

  def dispatch_webhook(event, path_version)
    # Verify signature
    body = request.body.read
    request.body.rewind

    begin
      KiketSDK::Auth.verify_signature(
        @config[:webhook_secret],
        body,
        request.env
      )
    rescue KiketSDK::Auth::AuthenticationError => e
      halt 401, { error: e.message }.to_json
    end

    # Determine version
    requested_version = path_version ||
                       request.env["HTTP_X_KIKET_EVENT_VERSION"] ||
                       params["version"]

    if requested_version.nil? || requested_version.empty?
      halt 400, { error: "Event version required" }.to_json
    end

    # Get handler
    metadata = @registry.get(event, requested_version)
    if metadata.nil?
      halt 404, { error: "No handler registered for event '#{event}' with version '#{requested_version}'" }.to_json
    end

    # Parse payload
    payload = JSON.parse(body)

    # Create client and context
    client = KiketSDK::Client.new(
      @config[:base_url],
      @config[:workspace_token],
      metadata[:version]
    )

    endpoints = KiketSDK::Endpoints.new(client, @config[:extension_id], metadata[:version])

    context = {
      event: event,
      event_version: metadata[:version],
      headers: extract_headers(request.env),
      client: client,
      endpoints: endpoints,
      settings: @config[:settings],
      extension_id: @config[:extension_id],
      extension_version: @config[:extension_version],
      secrets: endpoints.secrets
    }

    # Execute handler with telemetry
    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    begin
      result = metadata[:handler].call(payload, context)
      duration_ms = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000

      @telemetry.record(event, metadata[:version], "ok", duration_ms)

      content_type :json
      (result || { ok: true }).to_json
    rescue StandardError => e
      duration_ms = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000
      @telemetry.record(event, metadata[:version], "error", duration_ms, e.message)

      halt 500, { error: e.message }.to_json
    end
  end

  def resolve_config(config, manifest)
    base_url = config[:base_url] || ENV.fetch("KIKET_BASE_URL", "https://kiket.dev")
    workspace_token = config[:workspace_token] || ENV.fetch("KIKET_WORKSPACE_TOKEN", nil)
    webhook_secret = config[:webhook_secret] ||
                    manifest&.delivery_secret ||
                    ENV.fetch("KIKET_WEBHOOK_SECRET", nil)

    settings = {}
    if manifest
      settings.merge!(manifest.settings_defaults)
      settings.merge!(manifest.apply_secret_env_overrides) if config.fetch(:auto_env_secrets, true)
    end
    settings.merge!(config[:settings]) if config[:settings]

    extension_id = config[:extension_id] || manifest&.id
    extension_version = config[:extension_version] || manifest&.version
    telemetry_url = config[:telemetry_url] || ENV.fetch("KIKET_SDK_TELEMETRY_URL", nil)

    {
      webhook_secret: webhook_secret,
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
    env.select { |k, _| k.start_with?("HTTP_") }
       .transform_keys { |k| k.sub(/^HTTP_/, "").tr("_", "-").downcase }
  end
end
