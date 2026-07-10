# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'USSD app' do
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  it 'returns a friendly error for empty request bodies' do
    post '/', {}, { 'CONTENT_TYPE' => 'application/json' }

    expect(last_response.status).to eq(200)
    expect(JSON.parse(last_response.body)).to include(
      'display_message' => 'Invalid request payload.'
    )
  end

  it 'clears the resume pointer when a user chooses to start fresh' do
    msisdn = '233240000000'
    old_session_id = 'old-session'
    new_session_id = 'new-session'

    $redis.del("#{msisdn}-last-session")
    $redis.del("#{old_session_id}-#{msisdn}-cache")
    $redis.del("#{new_session_id}-#{msisdn}-cache")

    $redis.set("#{msisdn}-last-session", old_session_id, ex: 300)
    $redis.hset("#{old_session_id}-#{msisdn}-cache", { cache: { tracker: { function: 'main_menu' } }.to_json })

    expect(Cache.find_previous_session(msisdn, new_session_id)).not_to be_nil

    Cache.clear_previous_session(msisdn)

    expect(Cache.find_previous_session(msisdn, new_session_id)).to be_nil
  end
end
