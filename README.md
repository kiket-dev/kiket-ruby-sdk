# Kiket Ruby SDK

> Build and run Kiket extensions with a batteries-included, strongly-typed Ruby toolkit.

## Features

- 🔌 **Webhook decorators** – define handlers with `sdk.webhook("issue.created", version: "v1")`.
- 🔐 **Transparent authentication** – HMAC verification for inbound payloads, workspace-token client for outbound calls.
- 🔑 **Secret manager** – list, fetch, rotate, and delete extension secrets stored in Google Secret Manager.
- 🌐 **Built-in Sinatra app** – serve extension webhooks locally or in production without extra wiring.
- 🔁 **Version-aware routing** – register multiple handlers per event and propagate version headers on outbound calls.
- 📦 **Manifest-aware defaults** – automatically loads `extension.yaml`/`manifest.yaml`, applies configuration defaults, and hydrates secrets from `KIKET_SECRET_*` environment variables.
- 📇 **Custom data helper** – call `/api/v1/ext/custom_data/...` with `context[:endpoints].custom_data(project_id)` using the configured extension API key.
- 📉 **Rate-limit helper** – inspect `/api/v1/ext/rate_limit` before launching heavy automation bursts.
- 🧱 **Typed & documented** – designed for Ruby 3.2+ with rich documentation.
- 📊 **Telemetry & feedback hooks** – capture handler duration/success metrics automatically.

## Quickstart

```bash
gem install kiket-sdk
```

```ruby
# main.rb
require 'kiket_sdk'

sdk = KiketSDK.new(
  webhook_secret: 'sh_123',
  workspace_token: 'wk_test',
  extension_id: 'com.example.marketing',
  extension_version: '1.0.0'
)

# Register webhook handler (v1)
sdk.register('issue.created', version: 'v1') do |payload, context|
  summary = payload['issue']['title']
  puts "Event version: #{context[:event_version]}"

  context[:endpoints].log_event('issue.created', summary: summary)
  context[:secrets].set('WEBHOOK_TOKEN', 'abc123')

  { ok: true }
end

# Register webhook handler (v2)
sdk.register('issue.created', version: 'v2') do |payload, context|
  summary = payload['issue']['title']

  context[:endpoints].log_event('issue.created', summary: summary, schema: 'v2')

  { ok: true, version: context[:event_version] }
end

sdk.run!(host: '0.0.0.0', port: 8080)
```

### Custom Data Client

When your manifest includes `custom_data.permissions`, set `extension_api_key` (or the `KIKET_EXTENSION_API_KEY` environment variable) so outbound calls to the extension API include `X-Kiket-API-Key`:

```ruby
sdk.register('issue.created', version: 'v1') do |payload, context|
  project_id = payload.dig('issue', 'project_id')
  custom_data = context[:endpoints].custom_data(project_id)

  list = custom_data.list('com.example.crm.contacts', 'automation_records', limit: 10, filters: { status: 'active' })

  custom_data.create('com.example.crm.contacts', 'automation_records', {
    email: 'lead@example.com',
    metadata: { source: 'webhook' }
  })

  { synced: list['data'].size }
end
```

### SLA Alert Stream

You can also query live SLA alerts from within webhook handlers:

```ruby
sdk.register('workflow.sla_status', version: 'v1') do |payload, context|
  project_id = payload.dig('issue', 'project_id')
  sla_events = context[:endpoints].sla_events(project_id)

  events = sla_events.list(state: 'imminent', limit: 5)
  next { ok: true } if events['data'].empty?

  first = events['data'].first
  context[:endpoints].secrets # available if you need per-alert secrets

  context[:endpoints].log_event('sla.warning', issue_id: first['issue_id'], state: first['state'])
  { acknowledged: true }
end
```

## Configuration

### Environment Variables

- `KIKET_WEBHOOK_SECRET` – Webhook HMAC secret for signature verification
- `KIKET_WORKSPACE_TOKEN` – Workspace token for API authentication
- `KIKET_EXTENSION_API_KEY` – Extension API key for `/api/v1/ext/**` endpoints (custom data client)
- `KIKET_BASE_URL` – Kiket API base URL (defaults to `https://kiket.dev`)
- `KIKET_SDK_TELEMETRY_URL` – Telemetry reporting endpoint (optional)
- `KIKET_SDK_TELEMETRY_OPTOUT` – Set to `1` to disable telemetry
- `KIKET_SECRET_*` – Secret overrides (e.g., `KIKET_SECRET_API_KEY`)

### Manifest File

Create an `extension.yaml` or `manifest.yaml` file:

```yaml
id: com.example.marketing
version: 1.0.0
delivery_secret: sh_production_secret

settings:
  - key: API_KEY
    secret: true
  - key: MAX_RETRIES
    default: 3
  - key: TIMEOUT_MS
    default: 5000
```

## API Reference

### KiketSDK

Main SDK class for building extensions.

```ruby
sdk = KiketSDK.new(
  webhook_secret: String,
  workspace_token: String,
  base_url: String,
  settings: Hash,
  extension_id: String,
  extension_version: String,
  manifest_path: String,
  auto_env_secrets: Boolean,
  telemetry_enabled: Boolean,
  feedback_hook: Proc,
  telemetry_url: String
)
```

**Methods:**

- `sdk.register(event, version:, &handler)` – Register a webhook handler
- `sdk.webhook(event, version:)` – Decorator for registering handlers
- `sdk.run!(host:, port:)` – Start the Sinatra server

### Handler Context

Context hash passed to webhook handlers:

```ruby
{
  event: String,
  event_version: String,
  headers: Hash,
  client: KiketSDK::Client,
  endpoints: KiketSDK::Endpoints,
  settings: Hash,
  extension_id: String,
  extension_version: String,
  secrets: KiketSDK::Secrets,
  secret: Proc,              # Secret helper with payload-first fallback
  auth: {
    runtime_token: String,   # Per-invocation API token
    token_type: String,      # Typically "runtime"
    expires_at: String,      # Token expiration timestamp
    scopes: Array<String>    # Granted API scopes
  }
}
```

### Secret Helper

The `secret` proc provides a simple way to retrieve secrets with automatic fallback:

```ruby
# Checks payload secrets first (per-org config), falls back to ENV
slack_token = context[:secret].call("SLACK_BOT_TOKEN")

# Example usage
sdk.register('issue.created', version: 'v1') do |payload, context|
  api_key = context[:secret].call("API_KEY")
  raise "API_KEY not configured" unless api_key

  # Use api_key...
  { ok: true }
end
```

The lookup order is:
1. **Payload secrets** (per-org configuration from `payload["secrets"]`)
2. **Environment variables** (extension defaults via `ENV`)

This allows organizations to override extension defaults with their own credentials.

### Runtime Token Authentication

The Kiket platform sends a per-invocation `runtime_token` in each webhook payload. This token is automatically extracted and used for all API calls made through `context[:client]` and `context[:endpoints]`. The runtime token provides organization-scoped access and is preferred over static tokens.

```ruby
sdk.register('issue.created', version: 'v1') do |payload, context|
  # Access authentication context
  puts "Token expires at: #{context[:auth][:expires_at]}"
  puts "Scopes: #{context[:auth][:scopes].join(', ')}"

  # API calls automatically use the runtime token
  context[:endpoints].log_event('processed', { ok: true })

  { ok: true }
end
```

### Scope Checking

Extensions can declare required scopes when registering handlers. The SDK will automatically check scopes before invoking the handler and return a 403 error if insufficient.

```ruby
# Declare required scopes at registration time
sdk.register('issue.created', version: 'v1', required_scopes: ['issues.read', 'issues.write']) do |payload, context|
  # Handler only executes if scopes are present
  context[:endpoints].log_event('issue.processed', { id: payload['issue']['id'] })
  { ok: true }
end

# Or check scopes dynamically within the handler
sdk.register('workflow.triggered', version: 'v1') do |payload, context|
  # Raises KiketSDK::ScopeError if scopes are missing
  context[:require_scopes].call('workflows.execute', 'custom_data.write')

  # Continue with scope-protected operations
  context[:endpoints].custom_data(project_id).create(...)
  { ok: true }
end
```

## Testing

The SDK includes test helpers:

```ruby
require 'kiket_sdk'
require 'rack/test'

RSpec.describe 'My webhook handler' do
  include Rack::Test::Methods

  let(:sdk) do
    KiketSDK.new(webhook_secret: 'test-secret')
  end

  def app
    sdk
  end

  it 'handles issue.created event' do
    sdk.register('issue.created', version: 'v1') do |payload, context|
      { processed: payload['issue']['id'] }
    end

    payload = { issue: { id: '123', title: 'Test Issue' } }
    body = payload.to_json
    sig_data = KiketSDK::Auth.generate_signature('test-secret', body)

    post '/v/1/webhooks/issue.created',
         body,
         'CONTENT_TYPE' => 'application/json',
         'HTTP_X_KIKET_SIGNATURE' => sig_data[:signature],
         'HTTP_X_KIKET_TIMESTAMP' => sig_data[:timestamp]

    expect(last_response.status).to eq(200)
    expect(JSON.parse(last_response.body)['processed']).to eq('123')
  end
end
```

## Publishing to GitHub Packages

When you are ready to cut a release:

1. Update the version in `kiket-sdk.gemspec`.
2. Run the test suite (`bundle exec rspec`) and linting (`bundle exec rubocop`).
3. Build gem:
   ```bash
   gem build kiket-sdk.gemspec
   ```
4. Commit and tag the release:
   ```bash
   git add kiket-sdk.gemspec
   git commit -m "Bump Ruby SDK to v0.x.y"
   git tag ruby-v0.x.y
   git push --tags
   ```
5. GitHub Actions will automatically publish to GitHub Packages.

## License

MIT
### Rate-Limit Helper

Before enqueueing expensive jobs, inspect the current extension window:

```ruby
sandbox = sdk.register('automation.dispatch', version: 'v1') do |_payload, context|
  limits = context[:endpoints].rate_limit

  if limits['remaining'] < 5
    context[:endpoints].notify(
      'Rate limit warning',
      "Only #{limits['remaining']} requests remain (reset in #{limits['reset_in']}s)",
      'warning'
    )
    next({ deferred: true })
  end

  # Continue with the heavy work
  { ok: true }
end
```
