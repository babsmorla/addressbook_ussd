# frozen_string_literal: true

module Menu
  class Base
    include ::Validations rescue nil
    include ::Formatters rescue nil
    include ::Pagination rescue nil

    def initialize(params, data = nil)
      @params = params
      @mobile_number = params[:msisdn]
      @ussd_body = params[:ussd_body]
      @session_id = params[:session_id]
      @activity_type = params[:activity_type]
      @message_append = params[:message_append]
      @message_prepend = params[:message_prepend].to_s
      @end_session = false
      data ? @data = (data.is_a?(Hash) ? data.with_indifferent_access : {}) : fetch_data
    end

    def fetch_data
      cached_session = Cache.fetch(@params)
      @data = cached_session ? JSON.parse(cached_session.cache).with_indifferent_access : {}
    end

    def store_data(new_data = {})
      @data.merge!(new_data)
      Cache.store(@params.merge(cache: @data.to_json))
    end

    def render_page(function:, page: '1', activity_type: RESPONSE)
      tracker = { function: function, page: page, activity_type: activity_type }
      store_data(tracker: tracker)
      continue(@message_prepend + display_message)
    end

    def end_session(message)
      LOGGER.info("[Display → END] #{@mobile_number}: #{message}")
      Session::Manager.end(@params.merge(display_message: message))
    end

    def continue(message)
      LOGGER.info("[Display → CONTINUE] #{@mobile_number}: #{message}")
      Session::Manager.continue(@params.merge(display_message: message))
    end

    def display_message
      raise NotImplementedError, "#{self.class} has not implemented method 'display_message'"
    end
  end
end
