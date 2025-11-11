require 'spec_helper'

RSpec.describe KiketSDK::Endpoints do
  let(:client) { instance_double(KiketSDK::Client) }
  let(:endpoints) { described_class.new(client, 'ext-1', 'v1') }

  describe '#rate_limit' do
    it 'fetches the /api/v1/ext/rate_limit endpoint' do
      payload = { 'rate_limit' => { 'limit' => 600, 'remaining' => 42 } }
      expect(client).to receive(:get).with('/api/v1/ext/rate_limit').and_return(payload)

      result = endpoints.rate_limit

      expect(result).to eq(payload['rate_limit'])
    end
  end
end
