# frozen_string_literal: true

module Page
  module AddressBook
    class AddName < Page::Base
      def render_current_page
        render_page(function: ADD_CONTACT_NAME, activity_type: RESPONSE)
      end

      def process_response
        case @ussd_body
        when BACK
          Page::Gen::MainMenu.process(@params.merge(activity_type: REQUEST))
        else
          name = @ussd_body.to_s.strip
          return invalid_input('name') if name.empty?

          store_data(contact_name: name)
          Page::AddressBook::AddPhone.process(@params.merge(activity_type: REQUEST))
        end
      end

      def display_message
        "Add Contact\n\nEnter name:\n\n#{BACK}. Back"
      end
    end
  end
end
