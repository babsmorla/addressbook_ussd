# frozen_string_literal: true

require 'redis'

# Standard: Initialize Global Redis Client
# You can customize host/port via environment variables
unless defined?($redis)
  $redis = Redis.new(
    host: REDIS_HOST,
    port: REDIS_PORT,
    db:   REDIS_DB
  )

  LOGGER.info("[Redis] Connected to Redis at #{$redis.inspect}")
end
