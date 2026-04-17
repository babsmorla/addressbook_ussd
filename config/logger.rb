# frozen_string_literal: true

require 'logger'

# Standard: Standard daily rotation for USSD gateway logs
log_dir = File.expand_path('../log', __dir__)
Dir.mkdir(log_dir) unless Dir.exist?(log_dir)
log_file_path = File.join(log_dir, 'application.log')

class DailyLogger < Logger
  def initialize(log_file_path, keep_days)
    super(log_file_path, 'daily')
    @log_dir = File.dirname(log_file_path)
    @log_basename = File.basename(log_file_path)
    @keep_days = keep_days
  end
end

unless defined?(LOGGER)
  LOGGER = DailyLogger.new(log_file_path, 3) # Keep last 3 days
  LOGGER.level = Logger::INFO
end

# Link ActiveRecord logger to the same file
ActiveRecord::Base.logger = LOGGER if defined?(ActiveRecord)
