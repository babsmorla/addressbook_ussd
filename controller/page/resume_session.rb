# frozen_string_literal: true

module Page
  # Shared page — shown on first_dial when a previous session exists.
  # Offers the user the choice to resume or start fresh.
  class ResumeSession < Page::Base
    def render_current_page
      render_page(function: RESUME_SESSION, activity_type: RESPONSE)
    end

    def process_response
      case @ussd_body
      when '1'
        # Resume: migrate old data into this new session, then dispatch to the old page
        old_data = @data[:previous_session]
        if old_data
          Cache.migrate_session(@mobile_number, old_data, @session_id)
          function = old_data[:tracker][:function]
          MENU_MANAGER[function].process(
            @params.merge(activity_type: REQUEST)
          )
        else
          # Old data expired between screens — start fresh
          # Restart the flow
          Page::Gen::MainMenu.process(@params.merge(activity_type: REQUEST))
        end
      when '2', BACK
        # Start fresh
        Page::Gen::MainMenu.process(@params.merge(activity_type: REQUEST))
      else
        invalid_input
      end
    end

    def display_message
      "You have an active session.\n\n1. Continue where you left off\n2. Start fresh\n\n#{BACK}. Exit"
    end
  end
end
