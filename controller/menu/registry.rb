# frozen_string_literal: true

# Loaded LAST — after all page classes are defined.
# Maps tracker[:function] keys to their Page class entry points.
MENU_MANAGER = {
  MAINMENU             => Page::Gen::MainMenu,
  MAKE_PAYMENT         => Page::Gen::Payment,
  MAKE_PAYMENT_SUMMARY => Page::Gen::Summary,
  MAKE_PAYMENT_LAST    => Page::Gen::Last,
  ADD_CONTACT_NAME     => Page::AddressBook::AddName,
  ADD_CONTACT_PHONE    => Page::AddressBook::AddPhone,
  ADD_CONTACT_SUMMARY  => Page::AddressBook::AddSummary,
  CONTACT_LIST         => Page::AddressBook::ContactList,
  CONTACT_DETAILS      => Page::AddressBook::Details,
  EDIT_CONTACT_MENU    => Page::AddressBook::EditMenu,
  EDIT_CONTACT_NAME    => Page::AddressBook::EditName,
  EDIT_CONTACT_PHONE   => Page::AddressBook::EditPhone,
  DELETE_CONTACT       => Page::AddressBook::DeleteConfirm,
  CONTACT_US           => Page::ContactUs,
  RESUME_SESSION       => Page::ResumeSession
}.freeze
