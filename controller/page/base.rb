# frozen_string_literal: true

module Page
  class Base < Menu::Base
    def self.process(params, data = nil)
      new(params, data).process
    end

    def process
      case @activity_type
      when REQUEST
        render_current_page
      when RESPONSE
        process_response
      end
    end

    def render_current_page
      render_page(function: @params[:tracker] ? @params[:tracker][:function] : MAINMENU)
    end

    def process_response
      raise NotImplementedError, "#{self.class} has not implemented method 'process_response'"
    end

    def invalid_input(hint = 'option')
      @message_prepend = "Invalid #{hint}\n\n"
      render_current_page
    end
  end
end
