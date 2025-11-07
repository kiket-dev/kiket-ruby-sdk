# frozen_string_literal: true

require 'openssl'

class KiketSDK
  ##
  # HMAC signature verification for webhook payloads.
  module Auth
    class AuthenticationError < StandardError; end

    module_function

    def verify_signature(secret, body, headers)
      raise AuthenticationError, 'Webhook secret not configured' if secret.nil?

      signature = headers['HTTP_X_KIKET_SIGNATURE']
      timestamp = headers['HTTP_X_KIKET_TIMESTAMP']

      raise AuthenticationError, 'Missing X-Kiket-Signature header' if signature.nil?
      raise AuthenticationError, 'Missing X-Kiket-Timestamp header' if timestamp.nil?

      # Check timestamp (5 minute window)
      now = Time.now.to_i
      request_time = timestamp.to_i
      time_diff = (now - request_time).abs

      raise AuthenticationError, 'Request timestamp too old' if time_diff > 300

      # Compute expected signature
      payload = "#{timestamp}.#{body}"
      expected_signature = OpenSSL::HMAC.hexdigest('SHA256', secret, payload)

      # Constant-time comparison
      return if Rack::Utils.secure_compare(signature, expected_signature)

      raise AuthenticationError, 'Invalid signature'
    end

    def generate_signature(secret, body, timestamp = nil)
      timestamp ||= Time.now.to_i
      payload = "#{timestamp}.#{body}"
      signature = OpenSSL::HMAC.hexdigest('SHA256', secret, payload)

      { signature: signature, timestamp: timestamp.to_s }
    end
  end
end
