# frozen_string_literal: true

module Service
  # Service::Base wraps external-API / business-logic calls invoked from
  # Dial::Manager or a Page. Subclasses implement action methods (e.g.
  # `retrieve_entity_info`) that read from @params / @mobile_number / @data
  # — all inherited from Menu::Base.
  #
  # Convention:
  #   Service::Base.process(:retrieve_entity_info, @params)
  # invokes `Service::Base.new(@params).retrieve_entity_info` and catches
  # any error, logging it and returning nil so the caller can gracefully
  # end the session.
  class Base < Menu::Base
    def self.process(action, params = {})
      new(params).send(action)
    rescue StandardError => e
      LOGGER.error("[Service::#{name.split('::').last}] Action: #{action} — #{e.message}\n#{e.backtrace[0..3].join("\n")}")
      nil
    end

    private

    def retrieve_entity_info
      data = {
        mobile_number: @mobile_number,
        service_code:  extract_service_code
      }

      response = ExternalApi.get_request(RETRIEVE_ENTITY_INFO, data)

      return nil unless response && response[:resp_code] == '000'

      store_data(entity_info: response[:data])
      response[:data]
    end

    # Strips telco-prefix noise from the dial string.
    # Examples: "*447*8115#" → "8115", "8115" → "8115"
    def extract_service_code
      body = @params[:ussd_body].to_s.gsub('#', '')
      body.include?('*') ? body.split('*').last : body
    end
  end
end
