# frozen_string_literal: true

class CreateContacts < ActiveRecord::Migration[7.0]
  def change
    create_table :contacts do |t|
      t.string :msisdn, null: false
      t.string :name, null: false
      t.string :phone_number, null: false
      t.string :email
      t.text :notes
      t.timestamps
    end

    add_index :contacts, :msisdn
    add_index :contacts, %i[msisdn phone_number], unique: true
  end
end
