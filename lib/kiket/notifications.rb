# frozen_string_literal: true

module Kiket
  # Standard notification request for extension delivery
  class NotificationRequest
    attr_accessor :message, :channel_type, :channel_id, :recipient_id,
                  :format, :priority, :metadata, :thread_id, :attachments

    # @param message [String] The notification message content
    # @param channel_type [String] Type of channel ("channel", "dm", "group")
    # @param channel_id [String, nil] ID of the channel (for channel_type="channel")
    # @param recipient_id [String, nil] ID of the recipient (for channel_type="dm")
    # @param format [String] Message format ("plain", "markdown", "html")
    # @param priority [String] Notification priority ("low", "normal", "high", "urgent")
    # @param metadata [Hash, nil] Additional metadata for the notification
    # @param thread_id [String, nil] Optional thread ID for threaded messages
    # @param attachments [Array<Hash>, nil] Optional list of attachments
    def initialize(
      message:,
      channel_type:,
      channel_id: nil,
      recipient_id: nil,
      format: "markdown",
      priority: "normal",
      metadata: nil,
      thread_id: nil,
      attachments: nil
    )
      @message = message
      @channel_type = channel_type
      @channel_id = channel_id
      @recipient_id = recipient_id
      @format = format
      @priority = priority
      @metadata = metadata
      @thread_id = thread_id
      @attachments = attachments

      validate!
    end

    # @return [Hash] Hash representation for JSON serialization
    def to_h
      {
        message: @message,
        channel_type: @channel_type,
        channel_id: @channel_id,
        recipient_id: @recipient_id,
        format: @format,
        priority: @priority,
        metadata: @metadata,
        thread_id: @thread_id,
        attachments: @attachments
      }.compact
    end

    private

    def validate!
      raise ArgumentError, "Message content is required" if @message.nil? || @message.empty?

      unless %w[channel dm group].include?(@channel_type)
        raise ArgumentError, "Invalid channel_type: #{@channel_type}"
      end

      if @channel_type == "dm" && (@recipient_id.nil? || @recipient_id.empty?)
        raise ArgumentError, 'recipient_id is required for channel_type="dm"'
      end

      if @channel_type == "channel" && (@channel_id.nil? || @channel_id.empty?)
        raise ArgumentError, 'channel_id is required for channel_type="channel"'
      end

      unless %w[plain markdown html].include?(@format)
        raise ArgumentError, "Invalid format: #{@format}"
      end

      unless %w[low normal high urgent].include?(@priority)
        raise ArgumentError, "Invalid priority: #{@priority}"
      end
    end
  end

  # Standard notification response from extension
  class NotificationResponse
    attr_accessor :success, :message_id, :delivered_at, :error, :retry_after

    # @param success [Boolean] Whether the notification was delivered successfully
    # @param message_id [String, nil] ID of the delivered message
    # @param delivered_at [Time, String, nil] Timestamp when message was delivered
    # @param error [String, nil] Error message if delivery failed
    # @param retry_after [Integer, nil] Seconds to wait before retrying (for rate limits)
    def initialize(success:, message_id: nil, delivered_at: nil, error: nil, retry_after: nil)
      @success = success
      @message_id = message_id
      @delivered_at = delivered_at
      @error = error
      @retry_after = retry_after
    end

    # @return [Hash] Hash representation for JSON serialization
    def to_h
      result = { success: @success }
      result[:message_id] = @message_id if @message_id
      result[:delivered_at] = format_timestamp(@delivered_at) if @delivered_at
      result[:error] = @error if @error
      result[:retry_after] = @retry_after if @retry_after
      result
    end

    private

    def format_timestamp(timestamp)
      return timestamp.iso8601 if timestamp.respond_to?(:iso8601)

      timestamp.to_s
    end
  end

  # Request to validate a notification channel
  class ChannelValidationRequest
    attr_accessor :channel_id, :channel_type

    # @param channel_id [String] ID of the channel to validate
    # @param channel_type [String] Type of channel ("channel", "dm", "group")
    def initialize(channel_id:, channel_type: "channel")
      @channel_id = channel_id
      @channel_type = channel_type
    end

    # @return [Hash] Hash representation for JSON serialization
    def to_h
      {
        channel_id: @channel_id,
        channel_type: @channel_type
      }
    end
  end

  # Response from channel validation
  class ChannelValidationResponse
    attr_accessor :valid, :error, :metadata

    # @param valid [Boolean] Whether the channel is valid and accessible
    # @param error [String, nil] Error message if validation failed
    # @param metadata [Hash, nil] Additional channel metadata (name, member count, etc.)
    def initialize(valid:, error: nil, metadata: nil)
      @valid = valid
      @error = error
      @metadata = metadata
    end

    # @return [Hash] Hash representation for JSON serialization
    def to_h
      result = { valid: @valid }
      result[:error] = @error if @error
      result[:metadata] = @metadata if @metadata
      result
    end
  end
end
