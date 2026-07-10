# frozen_string_literal: true

module Menu
  class Manager < Menu::Base
    def self.process(params)
      new(params).process
    end

    def process
      tracker = @data[:tracker]
      function = tracker ? tracker[:function] : MAINMENU
      activity_type = tracker ? tracker[:activity_type] : REQUEST

      MENU_MANAGER[function].process(
        @params.merge(tracker: tracker, activity_type: activity_type)
      )
    end
  end
end
