# frozen_string_literal: true

module Page
  module AddressBook
    class AddPhone < Page::Base
      def render_current_page
        render_page(function: ADD_CONTACT_PHONE, activity_type: RESPONSE)
      end

      def process_response
        case @ussd_body
        when BACK
          Page::AddressBook::AddName.process(@params.merge(activity_type: REQUEST))
        else
          phone = @ussd_body.to_s.strip
          return invalid_input('phone number') unless valid_phone_number_format?(phone)

          store_data(contact_phone: format_mobile_number(phone))
          Page::AddressBook::AddSummary.process(@params.merge(activity_type: REQUEST))
        end
      end

      def display_message
        "Add Contact\n\nName: #{@data[:contact_name]}\nEnter phone number:\n\n#{BACK}. Back"
      end
    end
  end
end
