module Formatters
  def format_mobile_number(number)
    "233#{number[-9..]}"
  end
end
