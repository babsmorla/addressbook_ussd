# frozen_string_literal: true

require 'sinatra'
require 'sinatra/activerecord'
require 'faraday'
require 'json'
require 'erb'
require 'securerandom'
require 'active_support/all'

# Load shared utility code first so constants and helpers are available.
Dir['./util/**/*.rb'].sort.each { |file| require file }

# Initialize logging and Redis before the app starts processing requests.
require './config/logger'
require './config/redis'

# Load helpers, models, and controller classes used by the app.
Dir['./helpers/**/*.rb'].sort.each { |file| require file }
Dir['./models/**/*.rb'].sort.each { |file| require file }
require './controller/init'

enable :sessions
set :views, File.expand_path('views', __dir__)

helpers do
  # Keep a stable session identifier for each browser visitor.
  def current_session_id
    session[:session_id] ||= SecureRandom.hex(4)
  end

  # Provide a default phone number for demo USSD interactions.
  def default_msisdn
    session[:msisdn] ||= '233240000000'
  end

  # Clear the UI state when the user resets or finishes a flow.
  def reset_ui_state!
    session[:dial_buffer] = ''
    session[:input_buffer] = ''
    session[:ussd_active] = false
    session[:last_message] = ''
    session[:error_message] = nil
    session[:session_id] = "Babs"
  end

  # Build the payload sent to the dial manager and parse its response.
  def process_ussd_payload(msg_type:, ussd_body:)
    payload = {
      msisdn: default_msisdn,
      msg_type: msg_type,
      ussd_body: ussd_body,
      session_id: current_session_id
    }.to_json

    response = Dial::Manager.new(payload).process
    JSON.parse(response)
  rescue JSON::ParserError
    { 'display_message' => response.to_s, 'msg_type' => '2' }
  end
end

# Render the browser-based phone UI using the current session values.
get '/' do
 
  @dial_buffer = session[:dial_buffer].to_s
  @input_buffer = session[:input_buffer].to_s
  @ussd_active = session[:ussd_active] == true
  @display_message = session[:last_message].to_s
  @error_message = session[:error_message]
  @session_id = current_session_id

  erb :ui
end

# Handle form submissions from the UI and API-style JSON requests.
post '/' do
  if request.media_type.to_s.include?('application/json') || params[:json] == 'true'
    payload = request.body.read
    return Dial::Manager.new(payload).process
  end

  case params[:commit]
  when 'Reset'
    reset_ui_state!
    redirect '/'
  when 'Clear'
    if session[:ussd_active]
      session[:input_buffer] = session[:input_buffer].to_s[0...-1]
    else
      session[:dial_buffer] = session[:dial_buffer].to_s[0...-1]
    end
    redirect '/'
  end

  if params[:key_value].present?
    key = params[:key_value]
    if session[:ussd_active]
      session[:input_buffer] = "#{session[:input_buffer]}#{key}"
    else
      session[:dial_buffer] = "#{session[:dial_buffer]}#{key}"
    end
    redirect '/'
  end

  if params[:commit] == 'Dismiss'
    reset_ui_state!
    redirect '/'
  end

  if session[:ussd_active]
    user_input = params[:user_input].to_s.strip

    if user_input.empty?
      session[:error_message] = 'Please choose an option.'
      redirect '/'
    end

    result = process_ussd_payload(msg_type: '1', ussd_body: user_input)
    session[:last_message] = result['display_message'].to_s
    session[:ussd_active] = result['msg_type'].to_s == '1'
    session[:input_buffer] = ''
    session[:error_message] = nil
    redirect '/'
  else
    dial_value = params[:dial_value].to_s.strip
    dial_value = session[:dial_buffer].to_s if dial_value.empty?

    if dial_value.empty?
      session[:error_message] = 'Enter a short code.'
      redirect '/'
    end

    result = process_ussd_payload(msg_type: '0', ussd_body: dial_value)
    session[:last_message] = result['display_message'].to_s
    session[:ussd_active] = result['msg_type'].to_s == '1'
    session[:dial_buffer] = ''
    session[:input_buffer] = ''
    session[:error_message] = nil
    redirect '/'
  end
end
