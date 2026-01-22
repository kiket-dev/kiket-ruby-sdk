# frozen_string_literal: true

require 'spec_helper'

RSpec.describe KiketSDK do
  describe '.allow' do
    it 'returns a properly formatted allow response' do
      response = described_class.allow

      expect(response[:status]).to eq('allow')
      expect(response[:metadata]).to eq({})
    end

    it 'includes message when provided' do
      response = described_class.allow(message: 'Success')

      expect(response[:message]).to eq('Success')
    end

    it 'includes data in metadata' do
      response = described_class.allow(data: { route_id: 123, email: 'test@example.com' })

      expect(response[:metadata]).to include(route_id: 123, email: 'test@example.com')
    end

    it 'includes output_fields in metadata' do
      response = described_class.allow(
        output_fields: { 'inbound_email' => 'abc@parse.example.com' }
      )

      expect(response[:metadata]['output_fields']).to eq({ 'inbound_email' => 'abc@parse.example.com' })
    end

    it 'combines data and output_fields in metadata' do
      response = described_class.allow(
        message: 'Configured successfully',
        data: { route_id: 456 },
        output_fields: { 'webhook_url' => 'https://example.com/hook' }
      )

      expect(response[:status]).to eq('allow')
      expect(response[:message]).to eq('Configured successfully')
      expect(response[:metadata][:route_id]).to eq(456)
      expect(response[:metadata]['output_fields']).to eq({ 'webhook_url' => 'https://example.com/hook' })
    end

    it 'omits nil values using compact' do
      response = described_class.allow

      expect(response).not_to have_key(:message)
    end
  end

  describe '.deny' do
    it 'returns a properly formatted deny response' do
      response = described_class.deny(message: 'Access denied')

      expect(response[:status]).to eq('deny')
      expect(response[:message]).to eq('Access denied')
      expect(response[:metadata]).to eq({})
    end

    it 'includes data in metadata' do
      response = described_class.deny(
        message: 'Invalid credentials',
        data: { error_code: 'AUTH_FAILED' }
      )

      expect(response[:metadata]).to eq({ error_code: 'AUTH_FAILED' })
    end
  end

  describe '.pending' do
    it 'returns a properly formatted pending response' do
      response = described_class.pending(message: 'Awaiting approval')

      expect(response[:status]).to eq('pending')
      expect(response[:message]).to eq('Awaiting approval')
      expect(response[:metadata]).to eq({})
    end

    it 'includes data in metadata' do
      response = described_class.pending(
        message: 'Processing',
        data: { job_id: 'abc123' }
      )

      expect(response[:metadata]).to eq({ job_id: 'abc123' })
    end
  end
end
