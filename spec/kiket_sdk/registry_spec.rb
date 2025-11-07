# frozen_string_literal: true

require 'spec_helper'

RSpec.describe KiketSDK::Registry do
  let(:registry) { described_class.new }

  describe '#register' do
    it 'registers a handler' do
      handler = ->(payload, context) { { ok: true } }

      registry.register('test.event', 'v1', handler)

      metadata = registry.get('test.event', 'v1')
      expect(metadata).not_to be_nil
      expect(metadata[:event]).to eq('test.event')
      expect(metadata[:version]).to eq('v1')
      expect(metadata[:handler]).to eq(handler)
    end

    it 'allows multiple versions of same event' do
      handler_v1 = ->(payload, context) { { version: 'v1' } }
      handler_v2 = ->(payload, context) { { version: 'v2' } }

      registry.register('test.event', 'v1', handler_v1)
      registry.register('test.event', 'v2', handler_v2)

      expect(registry.get('test.event', 'v1')[:handler]).to eq(handler_v1)
      expect(registry.get('test.event', 'v2')[:handler]).to eq(handler_v2)
    end
  end

  describe '#get' do
    it 'returns nil for unregistered handler' do
      expect(registry.get('unknown.event', 'v1')).to be_nil
    end

    it 'returns handler metadata' do
      handler = ->(payload, context) { { ok: true } }
      registry.register('test.event', 'v1', handler)

      metadata = registry.get('test.event', 'v1')

      expect(metadata[:event]).to eq('test.event')
      expect(metadata[:version]).to eq('v1')
      expect(metadata[:handler]).to eq(handler)
    end
  end

  describe '#event_names' do
    it 'returns empty array when no handlers' do
      expect(registry.event_names).to eq([])
    end

    it 'returns unique event names' do
      registry.register('event1', 'v1', -> {})
      registry.register('event1', 'v2', -> {})
      registry.register('event2', 'v1', -> {})

      names = registry.event_names

      expect(names).to contain_exactly('event1', 'event2')
    end
  end

  describe '#all' do
    it 'returns all handlers' do
      registry.register('event1', 'v1', -> {})
      registry.register('event2', 'v1', -> {})

      expect(registry.all.size).to eq(2)
    end

    it 'returns empty array when no handlers' do
      expect(registry.all).to eq([])
    end
  end
end
