# frozen_string_literal: true

require 'spec_helper'
require 'tempfile'

RSpec.describe KiketSDK::Manifest do
  describe '.load' do
    it 'returns nil when no manifest file exists' do
      manifest = described_class.load

      expect(manifest).to be_nil
    end

    it 'loads manifest from file' do
      manifest_content = <<~YAML
        id: com.example.test
        version: 1.0.0
        delivery_secret: secret123
        settings:
          - key: API_KEY
            secret: true
          - key: MAX_RETRIES
            default: 3
      YAML

      Dir.mktmpdir do |dir|
        File.write(File.join(dir, 'extension.yaml'), manifest_content)
        Dir.chdir(dir) do
          manifest = described_class.load

          expect(manifest.id).to eq('com.example.test')
          expect(manifest.version).to eq('1.0.0')
          expect(manifest.delivery_secret).to eq('secret123')
          expect(manifest.settings.size).to eq(2)
        end
      end
    end
  end

  describe '#settings_defaults' do
    it 'returns hash of settings with default values' do
      data = {
        'id' => 'test',
        'version' => '1.0.0',
        'settings' => [
          { 'key' => 'API_KEY', 'secret' => true },
          { 'key' => 'MAX_RETRIES', 'default' => 3 },
          { 'key' => 'TIMEOUT', 'default' => 5000 }
        ]
      }

      manifest = described_class.new(data)
      defaults = manifest.settings_defaults

      expect(defaults).to eq({
                               'MAX_RETRIES' => 3,
                               'TIMEOUT' => 5000
                             })
    end

    it 'returns empty hash when no settings' do
      manifest = described_class.new({ 'id' => 'test', 'version' => '1.0.0' })

      expect(manifest.settings_defaults).to eq({})
    end
  end

  describe '#secret_keys' do
    it 'returns array of secret keys' do
      data = {
        'id' => 'test',
        'version' => '1.0.0',
        'settings' => [
          { 'key' => 'API_KEY', 'secret' => true },
          { 'key' => 'SECRET_TOKEN', 'secret' => true },
          { 'key' => 'MAX_RETRIES', 'default' => 3 }
        ]
      }

      manifest = described_class.new(data)
      secrets = manifest.secret_keys

      expect(secrets).to contain_exactly('API_KEY', 'SECRET_TOKEN')
    end

    it 'returns empty array when no secrets' do
      data = {
        'id' => 'test',
        'version' => '1.0.0',
        'settings' => [ { 'key' => 'MAX_RETRIES', 'default' => 3 } ]
      }

      manifest = described_class.new(data)

      expect(manifest.secret_keys).to eq([])
    end
  end

  describe '#apply_secret_env_overrides' do
    it 'applies environment variable overrides' do
      ENV['KIKET_SECRET_API_KEY'] = 'env-value'

      data = {
        'id' => 'test',
        'version' => '1.0.0',
        'settings' => [ { 'key' => 'API_KEY', 'secret' => true } ]
      }

      manifest = described_class.new(data)
      overrides = manifest.apply_secret_env_overrides

      expect(overrides).to eq({ 'API_KEY' => 'env-value' })

      ENV.delete('KIKET_SECRET_API_KEY')
    end

    it 'returns empty hash when no env vars set' do
      data = {
        'id' => 'test',
        'version' => '1.0.0',
        'settings' => [ { 'key' => 'API_KEY', 'secret' => true } ]
      }

      manifest = described_class.new(data)

      expect(manifest.apply_secret_env_overrides).to eq({})
    end
  end
end
