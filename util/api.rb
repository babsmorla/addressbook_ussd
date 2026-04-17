# frozen_string_literal: true

require 'faraday'

module Util
  module Api
    # The External Connection Layer. All REST API calls flow through here.
    # Enforces a USSD-friendly timeout so a hung backend can't stall the telco
    # session past its ~20s user-patience window.
    class Base
      DEFAULT_TIMEOUT = 10 # seconds — USSD hard limit

      def initialize(url, options = {})
        @url = url
        @options = options
        timeout = options[:timeout] || DEFAULT_TIMEOUT
        @conn = Faraday.new(url: @url) do |f|
          f.request :url_encoded
          f.adapter Faraday.default_adapter
          f.options.timeout = timeout
          f.options.open_timeout = timeout
        end
      end

      def post(path, body, headers = {})
        response = @conn.post(path) do |req|
          req.headers['Content-Type'] = 'application/json'
          req.headers.merge!(headers) if headers.any?
          req.body = body.to_json
        end
        LOGGER.info("[Api::Post] #{@url}#{path} — status=#{response.status}")
        Util::Api::Response.new(response)
      rescue StandardError => e
        LOGGER.error("[Api::Post] URL: #{@url}#{path} — Error: #{e.message}")
        nil
      end

      def get(path, params = {}, headers = {})
        response = @conn.get(path) do |req|
          req.headers['Content-Type'] = 'application/json'
          req.headers.merge!(headers) if headers.any?
          req.params = params
        end
        LOGGER.info("[Api::Get] #{@url}#{path} — status=#{response.status}")
        Util::Api::Response.new(response)
      rescue StandardError => e
        LOGGER.error("[Api::Get] URL: #{@url}#{path} — Error: #{e.message}")
        nil
      end
    end

    class Response
      attr_reader :status, :body

      def initialize(resp)
        @status = resp.status
        @body = (JSON.parse(resp.body)&.with_indifferent_access rescue {})
      end

      def success?
        @status >= 200 && @status < 300
      end
    end
  end
end

# ── Legacy compatibility shim ────────────────────────────────────────────────
# Pages still call ExternalApi.post_request / get_request and expect a plain
# hash back (not a Response wrapper). This shim delegates to Util::Api::Base
# so every call gets the timeout + logging, while existing pages continue to
# work unchanged.
class ExternalApi
  class << self
    def post_request(endpoint, body)
      response = client.post(endpoint, body)
      response&.body
    end

    def get_request(endpoint, params = {})
      response = client.get(endpoint, params.merge(limit: 100))
      response&.body
    end

    private

    def client
      @client ||= Util::Api::Base.new(BASE_URL)
    end
  end
end
