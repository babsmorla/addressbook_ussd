# frozen_string_literal: true

module Page
  module Gen
    class MainMenu < Page::Base
      def render_current_page
        render_page(function: MAINMENU, activity_type: RESPONSE)
      end

      def process_response
        case @ussd_body
        when '1'  then Page::Gen::Payment.process(@params.merge(activity_type: REQUEST))
        when '2'  then Page::ContactUs.process(@params.merge(activity_type: REQUEST, return_to: MAINMENU))
        when BACK then end_session('Thank you. Goodbye!')
        else
          invalid_input
        end
      end

      def display_message
        entity_name = @data.dig(:entity_info, :entity_name)
        header = entity_name ? "#{entity_name}\n#{APP_NAME}" : APP_NAME
        "#{header}\n\n1. Make Payment\n2. Contact Us\n\n#{BACK}. Exit"
      end
    end
  end
end
