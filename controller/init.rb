# frozen_string_literal: true

require './controller/menu/base' rescue nil
Dir['./controller/session/**/*.rb'].sort.each { |file| require file }
require './controller/service/base' rescue nil
Dir['./controller/service/**/*.rb'].sort.each { |file| require file }
require './controller/page/base' rescue nil
Dir['./controller/page/**/*.rb'].sort.each { |file| require file }
Dir['./controller/menu/**/*.rb'].sort.each { |file| require file }
Dir['./controller/dial/**/*.rb'].sort.each { |file| require file }
