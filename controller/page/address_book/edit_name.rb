# frozen_string_literal: true

module Page
  module AddressBook
    class EditName < Page::Base
      def render_current_page
        render_page(function: EDIT_CONTACT_NAME, activity_type: RESPONSE)
      end

      def process_response
        case @ussd_body
        when BACK
          Page::AddressBook::EditMenu.process(@params.merge(activity_type: REQUEST))
        else
          name = @ussd_body.to_s.strip
          return invalid_input('name') if name.empty?

          update_contact(name: name)
        end
      end

      def display_message
        "Edit Contact\n\nEnter new name:\n\n#{BACK}. Back"
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
