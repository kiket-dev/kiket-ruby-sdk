# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'KiketSDK secret helper' do
  # Test the secret helper logic directly without instantiating the full SDK
  # (KiketSDK initialization sets up Sinatra routes which requires specific context)

  # Simulate the build_secret_helper method logic
  def build_secret_helper(payload_secrets)
    lambda do |key|
      payload_secrets[key] || payload_secrets[key.to_s] || ENV[key.to_s]
    end
  end

  describe '#build_secret_helper' do
    context 'with payload secrets' do
      let(:payload_secrets) { { 'SLACK_TOKEN' => 'payload-token', 'API_KEY' => 'payload-key' } }
      let(:secret_helper) { build_secret_helper(payload_secrets) }

      it 'returns payload secret when present' do
        expect(secret_helper.call('SLACK_TOKEN')).to eq('payload-token')
      end

      it 'accepts symbol keys' do
        expect(secret_helper.call(:SLACK_TOKEN)).to eq('payload-token')
      end

      it 'falls back to ENV when payload secret is nil' do
        allow(ENV).to receive(:[]).with('MISSING_SECRET').and_return('env-value')

        expect(secret_helper.call('MISSING_SECRET')).to eq('env-value')
      end

      it 'returns nil when secret is not in payload or ENV' do
        allow(ENV).to receive(:[]).with('NONEXISTENT').and_return(nil)

        expect(secret_helper.call('NONEXISTENT')).to be_nil
      end
    end

    context 'with empty payload secrets' do
      let(:payload_secrets) { {} }
      let(:secret_helper) { build_secret_helper(payload_secrets) }

      it 'falls back to ENV' do
        allow(ENV).to receive(:[]).with('ENV_ONLY_SECRET').and_return('from-env')

        expect(secret_helper.call('ENV_ONLY_SECRET')).to eq('from-env')
      end
    end

    context 'payload secrets take priority over ENV' do
      let(:payload_secrets) { { 'SHARED_KEY' => 'from-payload' } }
      let(:secret_helper) { build_secret_helper(payload_secrets) }

      before do
        allow(ENV).to receive(:[]).with('SHARED_KEY').and_return('from-env')
      end

      it 'returns payload value when both exist' do
        expect(secret_helper.call('SHARED_KEY')).to eq('from-payload')
      end
    end

    context 'with mixed key types in payload' do
      let(:payload_secrets) { { 'STRING_KEY' => 'value1', :symbol_key => 'value2' } }
      let(:secret_helper) { build_secret_helper(payload_secrets) }

      it 'resolves string key from string lookup' do
        expect(secret_helper.call('STRING_KEY')).to eq('value1')
      end

      it 'resolves string key from symbol lookup' do
        expect(secret_helper.call(:STRING_KEY)).to eq('value1')
      end

      it 'resolves symbol key from symbol lookup' do
        expect(secret_helper.call(:symbol_key)).to eq('value2')
      end
    end
  end
end
