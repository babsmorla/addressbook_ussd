module Validations
  def valid_number?(quantity)
    quantity.is_a?(Numeric) && quantity > 0
  end

  def valid_phone_number_format?(number)
    number.match?(/^(0|233)\d{9}$/)
  end

  def invalid_option
    @message_prepend = "Invalid option\n"
    render_current_page
  end

  def valid_option?(ussd_body, options)
    if options.is_a?(Array)
      (1..options.length).include?(ussd_body.to_i)
    elsif options.is_a?(Range)
      ussd_body.to_i.between?(options.first, options.last)
    else
      options.include?(ussd_body.to_i)
    end
  end
end
