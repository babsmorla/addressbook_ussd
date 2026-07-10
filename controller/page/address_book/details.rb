# frozen_string_literal: true

module Page
  module AddressBook
    class Details < Page::Base
      def render_current_page
        render_page(function: CONTACT_DETAILS, activity_type: RESPONSE)
      end

      def process_response
        case @ussd_body
        when '1'
          Page::AddressBook::EditMenu.process(@params.merge(activity_type: REQUEST))
        when '2'
          Page::AddressBook::DeleteConfirm.process(@params.merge(activity_type: REQUEST))
        when BACK
          Page::AddressBook::ContactList.process(@params.merge(activity_type: REQUEST))
        else
          invalid_input
        end
      end

      def display_message
        contact = Service::AddressBook.process(:find_contact, @params, @data)
        return "Contact not found.\n\n#{BACK}. Back" unless contact

        <<~MSG
          Contact Details

          Name: #{contact.name}
          Phone: #{contact.phone_number}

          1. Edit
          2. Delete
          #{BACK}. Back
        MSG
      end
    end
  end
end
