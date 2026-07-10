# frozen_string_literal: true

module Service
  class AddressBook < Service::Base
    def create_contact
      Contact.create!(
        msisdn: @mobile_number,
        name: @data[:contact_name],
        phone_number: @data[:contact_phone]
      )
    end

    def list_contacts
      Contact.where(msisdn: @mobile_number).order(:name, :id).to_a
    end

    def find_contact
      Contact.where(msisdn: @mobile_number).find_by(id: @data[:selected_contact_id])
    end

    def update_contact
      contact = find_contact
      return nil unless contact

      contact.update!(@params[:contact_attrs] || {})
      contact
    end

    def delete_contact
      find_contact&.destroy
    end
  end
end
