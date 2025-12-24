require 'spec_helper'

RSpec.describe KiketSDK::IntakeForms do
  let(:client) { instance_double(KiketSDK::Client) }
  let(:intake_forms) { described_class.new(client, 'proj-42') }

  describe '#list' do
    it 'lists forms with default params' do
      expect(client).to receive(:get).with(
        '/ext/intake_forms?project_id=proj-42'
      )

      intake_forms.list
    end

    it 'filters by active and public' do
      expect(client).to receive(:get).with(
        '/ext/intake_forms?project_id=proj-42&active=true&public=true&limit=10'
      )

      intake_forms.list(active: true, public_only: true, limit: 10)
    end
  end

  describe '#get' do
    it 'fetches a form by key' do
      expect(client).to receive(:get).with(
        '/ext/intake_forms/bug-report?project_id=proj-42'
      )

      intake_forms.get('bug-report')
    end

    it 'requires form_key' do
      expect { intake_forms.get(nil) }.to raise_error(ArgumentError)
      expect { intake_forms.get('') }.to raise_error(ArgumentError)
    end
  end

  describe '#list_submissions' do
    it 'lists submissions for a form' do
      expect(client).to receive(:get).with(
        '/ext/intake_forms/bug-report/submissions?project_id=proj-42'
      )

      intake_forms.list_submissions('bug-report')
    end

    it 'filters by status and limit' do
      expect(client).to receive(:get).with(
        '/ext/intake_forms/bug-report/submissions?project_id=proj-42&status=pending&limit=20'
      )

      intake_forms.list_submissions('bug-report', status: 'pending', limit: 20)
    end

    it 'handles since parameter with Time' do
      time = Time.utc(2024, 1, 15, 10, 30, 0)
      expect(client).to receive(:get).with(
        '/ext/intake_forms/bug-report/submissions?project_id=proj-42&since=2024-01-15T10%3A30%3A00Z'
      )

      intake_forms.list_submissions('bug-report', since: time)
    end
  end

  describe '#get_submission' do
    it 'fetches a submission by ID' do
      expect(client).to receive(:get).with(
        '/ext/intake_forms/bug-report/submissions/sub-123?project_id=proj-42'
      )

      intake_forms.get_submission('bug-report', 'sub-123')
    end

    it 'requires both form_key and submission_id' do
      expect { intake_forms.get_submission(nil, 'sub-123') }.to raise_error(ArgumentError)
      expect { intake_forms.get_submission('bug-report', nil) }.to raise_error(ArgumentError)
    end
  end

  describe '#create_submission' do
    it 'creates a submission' do
      expect(client).to receive(:post).with(
        '/ext/intake_forms/bug-report/submissions',
        {
          project_id: 'proj-42',
          data: { title: 'Bug found', description: 'Details' }
        }
      )

      intake_forms.create_submission('bug-report', { title: 'Bug found', description: 'Details' })
    end

    it 'includes metadata when provided' do
      expect(client).to receive(:post).with(
        '/ext/intake_forms/bug-report/submissions',
        {
          project_id: 'proj-42',
          data: { title: 'Bug' },
          metadata: { source: 'api' }
        }
      )

      intake_forms.create_submission('bug-report', { title: 'Bug' }, metadata: { source: 'api' })
    end

    it 'requires form_key and data' do
      expect { intake_forms.create_submission(nil, {}) }.to raise_error(ArgumentError)
      expect { intake_forms.create_submission('bug-report', nil) }.to raise_error(ArgumentError)
      expect { intake_forms.create_submission('bug-report', 'not a hash') }.to raise_error(ArgumentError)
    end
  end

  describe '#approve_submission' do
    it 'approves a submission' do
      expect(client).to receive(:post).with(
        '/ext/intake_forms/bug-report/submissions/sub-123/approve',
        { project_id: 'proj-42' }
      )

      intake_forms.approve_submission('bug-report', 'sub-123')
    end

    it 'includes notes when provided' do
      expect(client).to receive(:post).with(
        '/ext/intake_forms/bug-report/submissions/sub-123/approve',
        { project_id: 'proj-42', notes: 'Looks good' }
      )

      intake_forms.approve_submission('bug-report', 'sub-123', notes: 'Looks good')
    end
  end

  describe '#reject_submission' do
    it 'rejects a submission' do
      expect(client).to receive(:post).with(
        '/ext/intake_forms/bug-report/submissions/sub-123/reject',
        { project_id: 'proj-42' }
      )

      intake_forms.reject_submission('bug-report', 'sub-123')
    end

    it 'includes notes when provided' do
      expect(client).to receive(:post).with(
        '/ext/intake_forms/bug-report/submissions/sub-123/reject',
        { project_id: 'proj-42', notes: 'Duplicate report' }
      )

      intake_forms.reject_submission('bug-report', 'sub-123', notes: 'Duplicate report')
    end
  end

  describe '#stats' do
    it 'fetches form stats' do
      expect(client).to receive(:get).with(
        '/ext/intake_forms/bug-report/stats?project_id=proj-42'
      )

      intake_forms.stats('bug-report')
    end

    it 'includes period when provided' do
      expect(client).to receive(:get).with(
        '/ext/intake_forms/bug-report/stats?project_id=proj-42&period=month'
      )

      intake_forms.stats('bug-report', period: 'month')
    end
  end

  it 'requires project_id on initialization' do
    expect { described_class.new(client, nil) }.to raise_error(ArgumentError)
    expect { described_class.new(client, '') }.to raise_error(ArgumentError)
    expect { described_class.new(client, '  ') }.to raise_error(ArgumentError)
  end
end
