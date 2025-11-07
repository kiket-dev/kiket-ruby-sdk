# frozen_string_literal: true

require "faraday"
require "faraday/retry"

class KiketSDK
  ##
  # HTTP client for Kiket API.
  class Client
    def initialize(base_url, workspace_token, event_version = nil)
      @workspace_token = workspace_token
      @event_version = event_version

      @conn = Faraday.new(url: base_url) do |f|
        f.request :json
        f.request :retry, max: 3, interval: 0.5
        f.response :json
        f.adapter Faraday.default_adapter

        f.headers["Content-Type"] = "application/json"
        f.headers["User-Agent"] = "kiket-sdk-ruby/#{KiketSDK::VERSION}"
      end
    end

    def get(path)
      response = @conn.get(path) do |req|
        add_auth_headers(req)
      end
      response.body
    end

    def post(path, data)
      response = @conn.post(path) do |req|
        add_auth_headers(req)
        req.body = data
      end
      response.body
    end

    def put(path, data)
      response = @conn.put(path) do |req|
        add_auth_headers(req)
        req.body = data
      end
      response.body
    end

    def delete(path)
      response = @conn.delete(path) do |req|
        add_auth_headers(req)
      end
      response.body
    end

    private

    def add_auth_headers(req)
      req.headers["Authorization"] = "Bearer #{@workspace_token}" if @workspace_token
      req.headers["X-Kiket-Event-Version"] = @event_version if @event_version
    end
  end
end
