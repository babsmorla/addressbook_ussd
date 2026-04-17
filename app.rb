# frozen_string_literal: true

require 'sinatra'
require 'sinatra/activerecord'
require 'faraday'
require 'json'
require 'active_support/all'

# Standard: Start with the Global Logger and Redis (V2 Standard)
require './config/logger'
require './config/redis'

# Standard: Initialize all sub-directories
Dir['./util/**/*.rb'].sort.each { |file| require file }
Dir['./helpers/**/*.rb'].sort.each { |file| require file }
Dir['./models/**/*.rb'].sort.each { |file| require file }

# Setup Controllers
require './controller/init'

post '/' do
  Dial::Manager.new(request.body.read).process
end
