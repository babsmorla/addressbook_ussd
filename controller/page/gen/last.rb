# frozen_string_literal: true

module Page
  module Gen
    class Last < Page::Base
      def render_current_page
        render_page(function: MAKE_PAYMENT_LAST, activity_type: RESPONSE)
      end

      def process_response
        case @ussd_body
        when BACK then Page::Gen::MainMenu.process(@params.merge(activity_type: REQUEST))
        else
          invalid_input
        end
      end

      def display_message
        "Thank you for using our service.\n\n#{BACK}. Back to Main Menu"
      end
    end
  end
end