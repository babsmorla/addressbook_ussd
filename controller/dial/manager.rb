# frozen_string_literal: true

module Dial
  class Manager
    def initialize(json)
      @params       = JSON.parse(json)&.with_indifferent_access
      @message_type = @params[:msg_type]
      @mobile_number = @params[:msisdn]
      @ussd_body    = @params[:ussd_body]
    end

    def process
      LOGGER.info("[Dial::Manager] MSISDN: #{@mobile_number} — Type: #{@message_type} — Body: #{@ussd_body}")

      case @message_type
      when MSG_START    then first_dial
      when MSG_CONTINUE then Menu::Manager.process(@params)
      when MSG_RELEASE  then release
      else
        Session::Manager.end(@params.merge(display_message: 'Unknown session type.'))
      end
    rescue StandardError => e
      LOGGER.error("[Dial::Manager] Error: #{e.message}\n#{e.backtrace[0..3].join("\n")}")
      Session::Manager.end(@params.merge(display_message: 'System error. Please try again.'))
    end

    private

    def first_dial
      # Check for a resumable session first
      previous = Cache.find_previous_session(@mobile_number, @params[:session_id])
      if previous
        Cache.store(@params.merge(cache: { previous_session: previous }.to_json))
        return Page::ResumeSession.process(@params.merge(activity_type: REQUEST))
      end

      # Retrieve the merchant entity by service code — fall back to GEN if unavailable
      entity_info = Service::Base.process(:retrieve_entity_info, @params)
      module_code = entity_info&.dig(:module) || GEN
      route_to_module(module_code)
    end

    # Determines which module's main menu page to show based on the API response.
    # Add new modules here as the platform grows.
    def route_to_module(module_code)
      case module_code
      when GEN
        Page::Gen::MainMenu.process(@params.merge(activity_type: REQUEST))
      else
        # Default to GEN for any unknown module
        LOGGER.info("[Dial::Manager] Unknown module '#{module_code}' — defaulting to GEN")
        Page::Gen::MainMenu.process(@params.merge(activity_type: REQUEST))
      end
    end

    def release
      $redis.del("#{@params[:session_id]}-#{@mobile_number}-cache")
      $redis.del("#{@mobile_number}-last-session")
      Session::Manager.end(@params.merge(display_message: ''))
    end
  end
end
