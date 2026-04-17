# frozen_string_literal: true

module Service
  class Gen < Service::Base
    def make_payment
      data = {
        session_id: @session_id,
        msisdn:     @mobile_number,
        amount:     @data[:amount],
        src:        'USSD'
      }

      response = ExternalApi.post_request(MAKE_PAYMENT_API, data)

      if response && response[:resp_code] == '000'
        end_session("Payment of #{CURRENCY} #{@data[:amount]} submitted.\n#{THANK_YOU}")
      elsif response && response[:resp_code] == '085'
        end_session('Insufficient funds. Please top up and try again.')
      else
        LOGGER.info("[Service::Gen] make_payment response: #{response.inspect}")
        end_session(response ? response[:resp_desc] : 'Service unavailable. Please try again.')
      end
    rescue StandardError => e
      LOGGER.error("[Service::Gen] make_payment error: #{e.message}")
      end_session('Failed to process payment. Please try again.')
    end
  end
end
