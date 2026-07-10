# frozen_string_literal: true

module Page
  module AddressBook
    class ContactList < Page::Base
      def render_current_page
        page = @params[:page] || @params.dig(:tracker, :page) || '1'
        render_page(function: CONTACT_LIST, page: page.to_s, activity_type: RESPONSE)
      end

      def process_response
        current_page = (@params.dig(:tracker, :page) || '1').to_i

        case @ussd_body
        when BACK
          Page::Gen::MainMenu.process(@params.merge(activity_type: REQUEST))
        when NEXT, PREV
          Page::AddressBook::ContactList.process(
            @params.merge(activity_type: REQUEST, page: resolve_page(@ussd_body, current: current_page))
          )
        else
          contacts = contacts_for_page(current_page)
          selected = contacts[@ussd_body.to_i - 1]
          return invalid_input if selected.nil?

          store_data(selected_contact_id: selected.id)
          Page::AddressBook::Details.process(@params.merge(activity_type: REQUEST))
        end
      end

      def display_message
        current_page = (@params[:page] || @params.dig(:tracker, :page) || '1').to_i
        contacts = Service::AddressBook.process(:list_contacts, @params, @data) || []
        return "Contacts\n\nNo contacts saved yet.\n\n#{BACK}. Back" if contacts.empty?

        paged = paginate(contacts, page: current_page)
        lines = paged.each_with_index.map { |contact, index| "#{index + 1}. #{contact.name}" }

        "Contacts\n\n#{lines.join("\n")}#{nav_options(paged)}\n#{BACK}. Back"
      end

      private

      def contacts_for_page(page)
        contacts = Service::AddressBook.process(:list_contacts, @params, @data) || []
        paginate(contacts, page: page)
      end
    end
  end
end
