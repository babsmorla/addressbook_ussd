# frozen_string_literal: true

class Contact < ActiveRecord::Base
  validates :msisdn, :name, :phone_number, presence: true
  validates :phone_number, uniqueness: { scope: :msisdn }
end
