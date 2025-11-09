require 'spec_helper'

RSpec.describe KiketSDK::SlaEvents do
  let(:client) { instance_double(KiketSDK::Client) }
  let(:sla_events) { described_class.new(client, 'proj-7') }

  describe '#list' do
    it 'encodes query params' do
      expect(client).to receive(:get).with(
        '/ext/sla/events?project_id=proj-7&issue_id=42&state=breached&limit=5'
      )

      sla_events.list(issue_id: 42, state: 'breached', limit: 5)
    end
  end

  it 'requires project id' do
    expect { described_class.new(client, nil) }.to raise_error(ArgumentError)
  end
end
