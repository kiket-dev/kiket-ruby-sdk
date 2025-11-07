# frozen_string_literal: true

require 'spec_helper'

RSpec.describe KiketSDK::Auth do
  describe '.verify_signature' do
    let(:secret) { 'test-secret' }
    let(:body) { '{"test":"data"}' }

    it 'verifies valid signature' do
      signature_data = described_class.generate_signature(secret, body)
      headers = {
        'HTTP_X_KIKET_SIGNATURE' => signature_data[:signature],
        'HTTP_X_KIKET_TIMESTAMP' => signature_data[:timestamp]
      }

      expect do
        described_class.verify_signature(secret, body, headers)
      end.not_to raise_error
    end

    it 'raises error when secret is nil' do
      expect do
        described_class.verify_signature(nil, body, {})
      end.to raise_error(KiketSDK::Auth::AuthenticationError, /not configured/)
    end

    it 'raises error when signature header is missing' do
      headers = { 'HTTP_X_KIKET_TIMESTAMP' => '123456789' }

      expect do
        described_class.verify_signature(secret, body, headers)
      end.to raise_error(KiketSDK::Auth::AuthenticationError, /Missing.*Signature/)
    end

    it 'raises error when timestamp header is missing' do
      headers = { 'HTTP_X_KIKET_SIGNATURE' => 'abc123' }

      expect do
        described_class.verify_signature(secret, body, headers)
      end.to raise_error(KiketSDK::Auth::AuthenticationError, /Missing.*Timestamp/)
    end

    it 'raises error for invalid signature' do
      timestamp = Time.now.to_i.to_s
      headers = {
        'HTTP_X_KIKET_SIGNATURE' => 'invalid-signature',
        'HTTP_X_KIKET_TIMESTAMP' => timestamp
      }

      expect do
        described_class.verify_signature(secret, body, headers)
      end.to raise_error(KiketSDK::Auth::AuthenticationError, /Invalid signature/)
    end

    it 'raises error for old timestamp' do
      old_timestamp = (Time.now.to_i - 400).to_s # 400 seconds ago
      signature_data = described_class.generate_signature(secret, body, old_timestamp.to_i)
      headers = {
        'HTTP_X_KIKET_SIGNATURE' => signature_data[:signature],
        'HTTP_X_KIKET_TIMESTAMP' => old_timestamp
      }

      expect do
        described_class.verify_signature(secret, body, headers)
      end.to raise_error(KiketSDK::Auth::AuthenticationError, /too old/)
    end
  end

  describe '.generate_signature' do
    let(:secret) { 'test-secret' }
    let(:body) { '{"test":"data"}' }

    it 'generates signature and timestamp' do
      result = described_class.generate_signature(secret, body)

      expect(result[:signature]).to be_a(String)
      expect(result[:signature]).to match(/^[a-f0-9]{64}$/)
      expect(result[:timestamp]).to be_a(String)
    end

    it 'uses provided timestamp' do
      timestamp = 1_234_567_890
      result = described_class.generate_signature(secret, body, timestamp)

      expect(result[:timestamp]).to eq(timestamp.to_s)
    end
  end
end
