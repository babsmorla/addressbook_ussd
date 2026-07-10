# frozen_string_literal: true

module Page
  module AddressBook
    class EditMenu < Page::Base
      def render_current_page
        render_page(function: EDIT_CONTACT_MENU, activity_type: RESPONSE)
      end

      def process_response
        case @ussd_body
        when '1'
          Page::AddressBook::EditName.process(@params.merge(activity_type: REQUEST))
        when '2'
          Page::AddressBook::EditPhone.process(@params.merge(activity_type: REQUEST))
        when BACK
          Page::AddressBook::Details.process(@params.merge(activity_type: REQUEST))
        else
          invalid_input
        end
      end

      def display_message
        "Edit Contact\n\n1. Edit Name\n2. Edit Phone\n#{BACK}. Back"
      end
    end
  end
end
