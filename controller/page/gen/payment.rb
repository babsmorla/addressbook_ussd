# frozen_string_literal: true

module Page
  module Gen
    class Payment < Page::Base
      def render_current_page
        render_page(function: MAKE_PAYMENT, activity_type: RESPONSE)
      end

      def process_response
        case @ussd_body
        when BACK then Page::Gen::MainMenu.process(@params.merge(activity_type: REQUEST))
        else
          return invalid_input('amount') unless valid_amount?(@ussd_body)

          store_data(amount: @ussd_body)
          Page::Gen::Summary.process(@params.merge(activity_type: REQUEST))
        end
      end

      def display_message
        "Make Payment\n\nEnter Amount (#{CURRENCY}):\n\n#{BACK}. Back"
      end
    end
  end
end

