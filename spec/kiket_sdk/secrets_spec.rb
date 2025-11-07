# frozen_string_literal: true

require 'spec_helper'

RSpec.describe KiketSDK::Secrets do
  let(:client) { instance_double(KiketSDK::Client) }
  let(:secrets) { described_class.new(client, 'test-extension') }

  describe '#get' do
    it 'retrieves a secret value' do
      allow(client).to receive(:get).with('/extensions/test-extension/secrets/API_KEY')
                                    .and_return({ 'value' => 'secret-value' })

      result = secrets.get('API_KEY')

      expect(result).to eq('secret-value')
    end

    it 'returns nil when secret not found' do
      allow(client).to receive(:get).and_raise(StandardError)

      result = secrets.get('MISSING_KEY')

      expect(result).to be_nil
    end
  end

  describe '#set' do
    it 'sets a secret value' do
      expect(client).to receive(:post).with(
        '/extensions/test-extension/secrets/API_KEY',
        { value: 'new-value' }
      )

      secrets.set('API_KEY', 'new-value')
    end
  end

  describe '#delete' do
    it 'deletes a secret' do
      expect(client).to receive(:delete).with('/extensions/test-extension/secrets/API_KEY')

      secrets.delete('API_KEY')
    end
  end

  describe '#list' do
    it 'lists all secret keys' do
      allow(client).to receive(:get).with('/extensions/test-extension/secrets')
                                    .and_return({ 'keys' => %w[API_KEY SECRET_TOKEN] })

      result = secrets.list

      expect(result).to eq(%w[API_KEY SECRET_TOKEN])
    end
  end

  describe '#rotate' do
    it 'rotates a secret' do
      expect(client).to receive(:delete).with('/extensions/test-extension/secrets/API_KEY')
      expect(client).to receive(:post).with(
        '/extensions/test-extension/secrets/API_KEY',
        { value: 'new-value' }
      )

      secrets.rotate('API_KEY', 'new-value')
    end
  end
end
