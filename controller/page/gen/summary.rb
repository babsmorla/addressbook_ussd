# frozen_string_literal: true

module Page
  module Gen
    class Summary < Page::Base
      def render_current_page
        render_page(function: MAKE_PAYMENT_SUMMARY, activity_type: RESPONSE)
      end

      def process_response
        case @ussd_body
        when CONFIRM then process_payment
        when BACK    then Page::Gen::Payment.process(@params.merge(activity_type: REQUEST))
        else              invalid_input
        end
      end

      private

      def process_payment
        Service::Gen.process(:make_payment, @params)
      end

      def display_message
        <<~MSG
          Summary

          Amount: #{CURRENCY} #{@data[:amount]}

          #{CONFIRM}. Confirm
          #{BACK}. Back
        MSG
      end
    end
  end
end
