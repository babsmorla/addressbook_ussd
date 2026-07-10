# frozen_string_literal: true

module Page
  module AddressBook
    class AddSummary < Page::Base
      def render_current_page
        render_page(function: ADD_CONTACT_SUMMARY, activity_type: RESPONSE)
      end

      def process_response
        case @ussd_body
        when '1'
          save_contact
        when '2'
          Page::AddressBook::AddName.process(@params.merge(activity_type: REQUEST))
        when '3'
          Page::AddressBook::AddPhone.process(@params.merge(activity_type: REQUEST))
        when BACK
          Page::Gen::MainMenu.process(@params.merge(activity_type: REQUEST))
        else
          invalid_input
        end
      end

      def display_message
        <<~MSG
          Confirm Contact

          Name: #{@data[:contact_name]}
          Phone: #{@data[:contact_phone]}

          1. Save
          2. Edit Name
          3. Edit Phone
          #{BACK}. Cancel
        MSG
      end

      private

      def save_contact
        contact = Service::AddressBook.process(:create_contact, @params, @data)
        return end_session("Contact saved.\n\n#{contact.name}: #{contact.phone_number}") if contact

        end_session('Unable to save contact. Please try again.')
      end
    end
  end
end
