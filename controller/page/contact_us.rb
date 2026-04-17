# frozen_string_literal: true

module Page
  # Shared across all modules — any page can route here via:
  #   Page::ContactUs.process(@params.merge(activity_type: REQUEST, return_to: SOME_FUNCTION))
  class ContactUs < Page::Base
    def render_current_page
      # Persist caller's return target so it survives the next turn (params reset each POST)
      store_data(contact_return_to: @params[:return_to]) if @params[:return_to]
      render_page(function: CONTACT_US, activity_type: RESPONSE)
    end

    def process_response
      # Return to whichever module called us, defaulting to the main menu page
      return_fn = @data[:contact_return_to] || MAINMENU
      MENU_MANAGER[return_fn]&.process(@params.merge(activity_type: REQUEST)) ||
        Page::Gen::MainMenu.process(@params.merge(activity_type: REQUEST))
    end

    def display_message
      "#{APP_NAME} Support\nTel: #{SUPPORT_PHONE}\nEmail: #{SUPPORT_EMAIL}\n\n#{BACK}. Back"
    end
  end
end
