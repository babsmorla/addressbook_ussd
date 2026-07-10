# frozen_string_literal: true

module Page
  module AddressBook
    class EditPhone < Page::Base
      def render_current_page
        render_page(function: EDIT_CONTACT_PHONE, activity_type: RESPONSE)
      end

      def process_response
        case @ussd_body
        when BACK
          Page::AddressBook::EditMenu.process(@params.merge(activity_type: REQUEST))
        else
          phone = @ussd_body.to_s.strip
          return invalid_input('phone number') unless valid_phone_number_format?(phone)

          update_contact(phone_number: format_mobile_number(phone))
        end
      end

      def display_message
        "Edit Contact\n\nEnter new phone number:\n\n#{BACK}. Back"
      end

      private

      def update_contact(attrs)
        contact = Service::AddressBook.process(:update_contact, @params.merge(contact_attrs: attrs), @data)
        return Page::AddressBook::Details.process(@params.merge(activity_type: REQUEST)) if contact

        end_session('Unable to update contact. Please try again.')
      end
    end
  end
end
