# frozen_string_literal: true

module Session
  class Base
    def initialize(params)
      @message_type = params[:msg_type]
      @ussd_body = params[:ussd_body]
      @params = params
      @display_message = params[:display_message]
    end

    def self.end(params)
      new(params).end
    end

    def self.continue(params)
      new(params).continue
    end
  end
end
