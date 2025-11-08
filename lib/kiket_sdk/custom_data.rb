# frozen_string_literal: true

require 'cgi'
require 'uri'

class KiketSDK
  ##
  # Client for the extension custom data API.
  class CustomData
    def initialize(client, project_id)
      raise ArgumentError, 'project_id is required' if project_id.nil? || project_id.to_s.strip.empty?

      @client = client
      @project_id = project_id.to_s
    end

    def list(module_key, table, limit: nil, filters: nil)
      @client.get(build_url(module_key, table, limit: limit, filters: filters))
    end

    def get(module_key, table, record_id)
      @client.get(build_url(module_key, table, record_id: record_id))
    end

    def create(module_key, table, record)
      @client.post(build_url(module_key, table), { record: record })
    end

    def update(module_key, table, record_id, record)
      @client.patch(build_url(module_key, table, record_id: record_id), { record: record })
    end

    def delete(module_key, table, record_id)
      @client.delete(build_url(module_key, table, record_id: record_id))
    end

    private

    def build_url(module_key, table, record_id: nil, limit: nil, filters: nil)
      path = "/ext/custom_data/#{CGI.escape(module_key)}/#{CGI.escape(table)}"
      path += "/#{record_id}" if record_id

      params = { project_id: @project_id }
      params[:limit] = limit if limit
      params[:filters] = filters.to_json if filters

      "#{path}?#{URI.encode_www_form(params)}"
    end
  end
end
