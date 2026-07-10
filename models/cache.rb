# frozen_string_literal: true

class Cache
  attr_accessor :mobile_number, :session_id, :cache

  def initialize(params)
    @session_id = params[:session_id]
    @mobile_number = params[:mobile_number]
    @cache = params[:cache] || '{}'
  end

  def self.store(params)
    session_id = params[:session_id]
    mobile_number = params[:msisdn]
    cache = { cache: params[:cache] }

    key = "#{session_id}-#{mobile_number}-cache"
    $redis.hset(key, cache)

    # Standard: Set TTL for session (5 minutes = 300 seconds)
    $redis.expire(key, 300)

    # Store a pointer so we can find this session by MSISDN alone
    $redis.set("#{mobile_number}-last-session", session_id, ex: 300)

    LOGGER.info("[Cache] Stored data for session: #{session_id}")
  end

  def self.fetch(params)
    session_id = params[:session_id]
    mobile_number = params[:msisdn]

    key = "#{session_id}-#{mobile_number}-cache"
    tracking_data = $redis.hgetall(key)

    # Standard: Handle empty hash from HGETALL
    if tracking_data.empty?
      nil
    else
      new(tracking_data.with_indifferent_access)
    end
  end

  # Check if there's a previous session for this MSISDN that can be resumed
  def self.find_previous_session(msisdn, current_session_id)
    old_session_id = $redis.get("#{msisdn}-last-session")
    return nil if old_session_id.nil? || old_session_id == current_session_id

    # Fetch the old session's data
    old_key = "#{old_session_id}-#{msisdn}-cache"
    old_data = $redis.hgetall(old_key)
    return nil if old_data.empty?

    parsed = JSON.parse(old_data['cache']).with_indifferent_access rescue nil
    return nil unless parsed&.dig(:tracker, :function)

    parsed
  end

  # Copy previous session data into the current session
  def self.migrate_session(msisdn, old_data, new_session_id)
    new_key = "#{new_session_id}-#{msisdn}-cache"
    $redis.hset(new_key, { cache: old_data.to_json })
    $redis.expire(new_key, 300)
    $redis.set("#{msisdn}-last-session", new_session_id, ex: 300)
    LOGGER.info("[Cache] Migrated previous session for #{msisdn} → #{new_session_id}")
  end


  # ================================================
  # Confirm later on this code
  # ================================================
  # Remove the resume pointer so the next start is treated as a fresh session.
  def self.clear_previous_session(msisdn)
    old_session_id = $redis.get("#{msisdn}-last-session")
    return if old_session_id.nil?

    $redis.del("#{msisdn}-last-session")
    $redis.del("#{old_session_id}-#{msisdn}-cache")
    $redis.del("#{msisdn}-cache")
    LOGGER.info("[Cache] Cleared previous session pointer for #{msisdn}")
  end

  # Fully reset all cached session state for a phone number.
  def self.reset_session_state(msisdn)
    clear_previous_session(msisdn)
    $redis.del("#{msisdn}-last-session")
    $redis.keys("*-#{msisdn}-cache").each { |key| $redis.del(key) }
    LOGGER.info("[Cache] Reset all session state for #{msisdn}")
  end
end

