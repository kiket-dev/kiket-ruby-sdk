# frozen_string_literal: true

require 'uri'

class KiketSDK
  ##
  # Helper for managing intake forms and submissions via the Kiket API.
  class IntakeForms
    def initialize(client, project_id)
      raise ArgumentError, 'project_id is required' if project_id.nil? || project_id.to_s.strip.empty?

      @client = client
      @project_id = project_id.to_s
    end

    ##
    # List all intake forms for the project.
    #
    # @param active [Boolean, nil] Filter by active status
    # @param public_only [Boolean, nil] Filter by public forms only
    # @param limit [Integer, nil] Maximum number of forms to return
    # @return [Hash] API response with forms array
    def list(active: nil, public_only: nil, limit: nil)
      params = { project_id: @project_id }
      params[:active] = active unless active.nil?
      params[:public] = public_only unless public_only.nil?
      params[:limit] = limit if limit

      query = URI.encode_www_form(params)
      @client.get("/ext/intake_forms?#{query}")
    end

    ##
    # Get a specific intake form by key or ID.
    #
    # @param form_key [String] The form key or ID
    # @return [Hash] The intake form details
    def get(form_key)
      raise ArgumentError, 'form_key is required' if form_key.nil? || form_key.to_s.strip.empty?

      @client.get("/ext/intake_forms/#{URI.encode_www_form_component(form_key)}?project_id=#{@project_id}")
    end

    ##
    # Get the public URL for a form.
    #
    # @param form_key [String] The form key
    # @return [String, nil] The public URL if the form is public
    def public_url(form_key)
      form = get(form_key)
      form['form_url'] if form['public']
    end

    ##
    # List submissions for an intake form.
    #
    # @param form_key [String] The form key or ID
    # @param status [String, nil] Filter by status (pending, approved, rejected, converted)
    # @param limit [Integer, nil] Maximum number of submissions to return
    # @param since [Time, String, nil] Only return submissions after this time
    # @return [Hash] API response with submissions array
    def list_submissions(form_key, status: nil, limit: nil, since: nil)
      raise ArgumentError, 'form_key is required' if form_key.nil? || form_key.to_s.strip.empty?

      params = { project_id: @project_id }
      params[:status] = status if status
      params[:limit] = limit if limit
      params[:since] = format_timestamp(since) if since

      query = URI.encode_www_form(params)
      @client.get("/ext/intake_forms/#{URI.encode_www_form_component(form_key)}/submissions?#{query}")
    end

    ##
    # Get a specific submission by ID.
    #
    # @param form_key [String] The form key or ID
    # @param submission_id [String] The submission ID
    # @return [Hash] The submission details
    def get_submission(form_key, submission_id)
      raise ArgumentError, 'form_key is required' if form_key.nil? || form_key.to_s.strip.empty?
      raise ArgumentError, 'submission_id is required' if submission_id.nil? || submission_id.to_s.strip.empty?

      @client.get("/ext/intake_forms/#{URI.encode_www_form_component(form_key)}/submissions/#{submission_id}?project_id=#{@project_id}")
    end

    ##
    # Create a new submission for an intake form.
    # This is typically used for internal/programmatic submissions.
    #
    # @param form_key [String] The form key or ID
    # @param data [Hash] The submission data (field values)
    # @param metadata [Hash, nil] Optional metadata
    # @return [Hash] The created submission
    def create_submission(form_key, data, metadata: nil)
      raise ArgumentError, 'form_key is required' if form_key.nil? || form_key.to_s.strip.empty?
      raise ArgumentError, 'data is required' if data.nil? || !data.is_a?(Hash)

      payload = {
        project_id: @project_id,
        data: data
      }
      payload[:metadata] = metadata if metadata

      @client.post("/ext/intake_forms/#{URI.encode_www_form_component(form_key)}/submissions", payload)
    end

    ##
    # Approve a pending submission.
    #
    # @param form_key [String] The form key or ID
    # @param submission_id [String] The submission ID
    # @param notes [String, nil] Optional approval notes
    # @return [Hash] The updated submission
    def approve_submission(form_key, submission_id, notes: nil)
      raise ArgumentError, 'form_key is required' if form_key.nil? || form_key.to_s.strip.empty?
      raise ArgumentError, 'submission_id is required' if submission_id.nil? || submission_id.to_s.strip.empty?

      payload = { project_id: @project_id }
      payload[:notes] = notes if notes

      @client.post("/ext/intake_forms/#{URI.encode_www_form_component(form_key)}/submissions/#{submission_id}/approve", payload)
    end

    ##
    # Reject a pending submission.
    #
    # @param form_key [String] The form key or ID
    # @param submission_id [String] The submission ID
    # @param notes [String, nil] Optional rejection notes
    # @return [Hash] The updated submission
    def reject_submission(form_key, submission_id, notes: nil)
      raise ArgumentError, 'form_key is required' if form_key.nil? || form_key.to_s.strip.empty?
      raise ArgumentError, 'submission_id is required' if submission_id.nil? || submission_id.to_s.strip.empty?

      payload = { project_id: @project_id }
      payload[:notes] = notes if notes

      @client.post("/ext/intake_forms/#{URI.encode_www_form_component(form_key)}/submissions/#{submission_id}/reject", payload)
    end

    ##
    # Get submission statistics for an intake form.
    #
    # @param form_key [String] The form key or ID
    # @param period [String, nil] Time period for stats (day, week, month)
    # @return [Hash] Statistics including counts by status
    def stats(form_key, period: nil)
      raise ArgumentError, 'form_key is required' if form_key.nil? || form_key.to_s.strip.empty?

      params = { project_id: @project_id }
      params[:period] = period if period

      query = URI.encode_www_form(params)
      @client.get("/ext/intake_forms/#{URI.encode_www_form_component(form_key)}/stats?#{query}")
    end

    private

    def format_timestamp(time)
      case time
      when Time, DateTime
        time.iso8601
      when String
        time
      else
        time.to_s
      end
    end
  end
end
