# frozen_string_literal: true

class KiketSDK
  ##
  # Extension secret manager.
  class Secrets
    def initialize(client, extension_id)
      @client = client
      @extension_id = extension_id
    end

    def get(key)
      response = @client.get("/extensions/#{@extension_id}/secrets/#{key}")
      response["value"]
    rescue StandardError
      nil
    end

    def set(key, value)
      @client.post("/extensions/#{@extension_id}/secrets/#{key}", { value: value })
    end

    def delete(key)
      @client.delete("/extensions/#{@extension_id}/secrets/#{key}")
    end

    def list
      response = @client.get("/extensions/#{@extension_id}/secrets")
      response["keys"]
    end

    def rotate(key, new_value)
      delete(key)
      set(key, new_value)
    end
  end
end
