# frozen_string_literal: true

class KiketSDK
  ##
  # Response helpers for building properly formatted extension responses.
  module Responses
    ##
    # Build an allow response with optional output fields.
    # Output fields are displayed in the extension configuration UI after setup.
    #
    # @param message [String] Optional success message
    # @param data [Hash] Additional metadata
    # @param output_fields [Hash] Key-value pairs to display in configuration UI
    # @return [Hash] Properly formatted response for Kiket
    #
    # @example
    #   KiketSDK.allow(
    #     message: 'Successfully configured',
    #     data: { route_id: 123 },
    #     output_fields: { inbound_email: 'abc@parse.example.com' }
    #   )
    def allow(message: nil, data: {}, output_fields: nil)
      metadata = data.dup
      metadata['output_fields'] = output_fields if output_fields
      {
        status: 'allow',
        message: message,
        metadata: metadata
      }.compact
    end

    ##
    # Build a deny response.
    #
    # @param message [String] Reason for denial
    # @param data [Hash] Additional metadata
    # @return [Hash] Properly formatted response for Kiket
    def deny(message:, data: {})
      {
        status: 'deny',
        message: message,
        metadata: data
      }
    end

    ##
    # Build a pending response (for async operations).
    #
    # @param message [String] Status message
    # @param data [Hash] Additional metadata
    # @return [Hash] Properly formatted response for Kiket
    def pending(message:, data: {})
      {
        status: 'pending',
        message: message,
        metadata: data
      }
    end
  end

  extend Responses
end
