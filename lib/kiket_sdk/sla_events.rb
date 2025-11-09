# frozen_string_literal: true

require 'uri'

class KiketSDK
  ##
  # Helper for querying workflow SLA events.
  class SlaEvents
    def initialize(client, project_id)
      raise ArgumentError, 'project_id is required' if project_id.nil? || project_id.to_s.strip.empty?

      @client = client
      @project_id = project_id.to_s
    end

    def list(issue_id: nil, state: nil, limit: nil)
      params = { project_id: @project_id }
      params[:issue_id] = issue_id if issue_id
      params[:state] = state if state
      params[:limit] = limit if limit

      query = URI.encode_www_form(params)
      @client.get("/ext/sla/events?#{query}")
    end
  end
end
