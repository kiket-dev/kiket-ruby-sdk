# frozen_string_literal: true

require 'spec_helper'

RSpec.describe KiketSDK::Client do
  let(:base_url) { 'https://api.test.com' }
  let(:workspace_token) { 'wk_test_token' }
  let(:extension_api_key) { 'ext_123' }
  let(:client) { described_class.new(base_url, workspace_token, 'v1', extension_api_key) }

  describe '#get' do
    it 'makes GET request with auth headers' do
      stub_request(:get, "#{base_url}/test")
        .with(headers: {
                'Authorization' => "Bearer #{workspace_token}",
                'X-Kiket-Event-Version' => 'v1',
                'X-Kiket-API-Key' => extension_api_key
              })
        .to_return(status: 200, body: '{"result":"success"}', headers: { 'Content-Type' => 'application/json' })

      result = client.get('/test')

      expect(result).to eq({ 'result' => 'success' })
    end
  end

  describe '#post' do
    it 'makes POST request with data' do
      stub_request(:post, "#{base_url}/test")
        .with(
          body: { name: 'test' }.to_json,
          headers: {
            'Authorization' => "Bearer #{workspace_token}",
            'X-Kiket-API-Key' => extension_api_key
          }
        )
        .to_return(status: 200, body: '{"id":"123"}', headers: { 'Content-Type' => 'application/json' })

      result = client.post('/test', { name: 'test' })

      expect(result).to eq({ 'id' => '123' })
    end
  end

  describe '#put' do
    it 'makes PUT request' do
      stub_request(:put, "#{base_url}/test")
        .with(body: { value: 'updated' }.to_json)
        .to_return(status: 200, body: '{"updated":true}', headers: { 'Content-Type' => 'application/json' })

      result = client.put('/test', { value: 'updated' })

      expect(result).to eq({ 'updated' => true })
    end
  end

  describe '#delete' do
    it 'makes DELETE request' do
      stub_request(:delete, "#{base_url}/test")
        .to_return(status: 200, body: '{"deleted":true}', headers: { 'Content-Type' => 'application/json' })

      result = client.delete('/test')

      expect(result).to eq({ 'deleted' => true })
    end
  end

  describe '#patch' do
    it 'makes PATCH request' do
      stub_request(:patch, "#{base_url}/test")
        .with(body: { value: 'patched' }.to_json)
        .to_return(status: 200, body: '{"patched":true}', headers: { 'Content-Type' => 'application/json' })

      result = client.patch('/test', { value: 'patched' })

      expect(result).to eq({ 'patched' => true })
    end
  end

  describe 'runtime token authentication' do
    let(:runtime_token) { 'rt_test_runtime_token' }
    let(:client_with_runtime_token) do
      described_class.new(base_url, workspace_token, 'v1', extension_api_key, runtime_token: runtime_token)
    end

    it 'uses runtime token header when provided' do
      stub_request(:get, "#{base_url}/test")
        .with(headers: {
                'Authorization' => "Bearer #{workspace_token}",
                'X-Kiket-Event-Version' => 'v1',
                'X-Runtime-Token' => runtime_token
              })
        .to_return(status: 200, body: '{"result":"success"}', headers: { 'Content-Type' => 'application/json' })

      result = client_with_runtime_token.get('/test')

      expect(result).to eq({ 'result' => 'success' })
    end

    it 'prefers runtime token over extension API key' do
      stub_request(:get, "#{base_url}/test")
        .with(headers: {
                'X-Runtime-Token' => runtime_token
              })
        .to_return(status: 200, body: '{"result":"success"}', headers: { 'Content-Type' => 'application/json' })

      # Verify that X-Kiket-API-Key is NOT present when runtime token is set
      stub = stub_request(:get, "#{base_url}/verify")
        .with { |request| !request.headers.key?('X-Kiket-API-Key') && request.headers['X-Runtime-Token'] == runtime_token }
        .to_return(status: 200, body: '{}', headers: { 'Content-Type' => 'application/json' })

      client_with_runtime_token.get('/verify')

      expect(stub).to have_been_requested
    end
  end
end
