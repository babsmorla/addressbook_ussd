# frozen_string_literal: true

module Session
  class Manager < Session::Base
    def continue
      parse_response('1')
    end

    def end
      parse_response('2')
    end

    private

    def parse_response(msg_type)
      @params[:ussd_body] = @display_message
      @params[:msg_type] = msg_type
      @params.to_json
    end
  end
end
