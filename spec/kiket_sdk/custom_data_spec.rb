require 'spec_helper'

RSpec.describe KiketSDK::CustomData do
  let(:client) { instance_double(KiketSDK::Client) }
  let(:custom_data) { described_class.new(client, 42) }

  describe '#list' do
    it 'passes project params and filters' do
      expect(client).to receive(:get).with(
        '/ext/custom_data/com.example.module/records?project_id=42&limit=10&filters=%7B%22status%22%3A%22active%22%7D'
      )

      custom_data.list('com.example.module', 'records', limit: 10, filters: { status: 'active' })
    end
  end

  describe '#create' do
    it 'posts record payload' do
      expect(client).to receive(:post).with(
        '/ext/custom_data/com.example.module/records?project_id=42',
        { record: { email: 'lead@example.com' } }
      )

      custom_data.create('com.example.module', 'records', { email: 'lead@example.com' })
    end
  end
end
