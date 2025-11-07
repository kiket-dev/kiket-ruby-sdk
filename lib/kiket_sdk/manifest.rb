# frozen_string_literal: true

require 'yaml'

class KiketSDK
  ##
  # Extension manifest loader.
  class Manifest
    attr_reader :id, :version, :delivery_secret, :settings

    def initialize(data)
      @id = data['id']
      @version = data['version']
      @delivery_secret = data['delivery_secret']
      @settings = (data['settings'] || []).map { |s| Setting.new(s) }
    end

    def self.load(path = nil)
      paths = path ? [path] : %w[extension.yaml manifest.yaml extension.yml manifest.yml]

      paths.each do |p|
        full_path = File.expand_path(p, Dir.pwd)
        next unless File.exist?(full_path)

        begin
          data = YAML.load_file(full_path)
          return new(data)
        rescue StandardError => e
          warn "Failed to parse manifest at #{full_path}: #{e.message}"
        end
      end

      nil
    end

    def settings_defaults
      @settings.each_with_object({}) do |setting, defaults|
        defaults[setting.key] = setting.default_value if setting.default_value
      end
    end

    def secret_keys
      @settings.select(&:secret?).map(&:key)
    end

    def apply_secret_env_overrides
      secret_keys.each_with_object({}) do |key, overrides|
        env_key = "KIKET_SECRET_#{key.upcase}"
        env_value = ENV.fetch(env_key, nil)
        overrides[key] = env_value if env_value
      end
    end

    ##
    # Setting definition.
    class Setting
      attr_reader :key, :default_value

      def initialize(data)
        @key = data['key']
        @default_value = data['default']
        @secret = data['secret'] == true
      end

      def secret?
        @secret
      end
    end
  end
end
