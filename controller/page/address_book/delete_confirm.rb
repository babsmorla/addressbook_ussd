# frozen_string_literal: true

module Page
  module AddressBook
    class DeleteConfirm < Page::Base
      def render_current_page
        render_page(function: DELETE_CONTACT, activity_type: RESPONSE)
      end

      def process_response
        case @ussd_body
        when '1'
          Service::AddressBook.process(:delete_contact, @params, @data)
          end_session('Contact deleted.')
        when '2', BACK
          Page::AddressBook::Details.process(@params.merge(activity_type: REQUEST))
        else
          invalid_input
        end
      end

      def display_message
        contact = Service::AddressBook.process(:find_contact, @params, @data)
        name = contact ? contact.name : 'this contact'

        "Delete #{name}?\n\n1. Yes, delete\n2. No, back"
      end
    end
  end
end
