# frozen_string_literal: true

# Loaded LAST — after all page classes are defined.
# Maps tracker[:function] keys to their Page class entry points.
MENU_MANAGER = {
  MAINMENU             => Page::Gen::MainMenu,
  MAKE_PAYMENT         => Page::Gen::Payment,
  MAKE_PAYMENT_SUMMARY => Page::Gen::Summary,
  CONTACT_US           => Page::ContactUs,
  RESUME_SESSION       => Page::ResumeSession
}.freeze
