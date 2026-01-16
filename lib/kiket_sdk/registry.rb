# frozen_string_literal: true

class KiketSDK
  ##
  # Registry for webhook handlers.
  class Registry
    def initialize
      @handlers = {}
    end

    def register(event, version, handler, required_scopes: [])
      key = make_key(event, version)
      @handlers[key] = {
        event: event,
        version: version,
        handler: handler,
        required_scopes: Array(required_scopes)
      }
    end

    def get(event, version)
      key = make_key(event, version)
      @handlers[key]
    end

    def event_names
      @handlers.values.map { |m| m[:event] }.uniq
    end

    def all
      @handlers.values
    end

    private

    def make_key(event, version)
      "#{event}:#{version}"
    end
  end
end
