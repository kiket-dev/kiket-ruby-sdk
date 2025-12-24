# frozen_string_literal: true

require_relative 'secrets'
require_relative 'custom_data'
require_relative 'sla_events'
require_relative 'intake_forms'

class KiketSDK
  ##
  # High-level extension endpoints.
  class Endpoints
    attr_reader :secrets

    def initialize(client, extension_id, event_version)
      @client = client
      @extension_id = extension_id
      @event_version = event_version
      @secrets = Secrets.new(client, extension_id)
    end

    def log_event(event, data)
      @client.post("/extensions/#{@extension_id}/events", {
                     event: event,
                     version: @event_version,
                     data: data,
                     timestamp: Time.now.iso8601
                   })
    end

    def get_metadata
      @client.get("/extensions/#{@extension_id}")
    end

    def custom_data(project_id)
      KiketSDK::CustomData.new(@client, project_id)
    end

    def sla_events(project_id)
      KiketSDK::SlaEvents.new(@client, project_id)
    end

    def intake_forms(project_id)
      KiketSDK::IntakeForms.new(@client, project_id)
    end

    def rate_limit
      response = @client.get("/api/v1/ext/rate_limit")
      response.fetch("rate_limit", {})
    end
  end
end
