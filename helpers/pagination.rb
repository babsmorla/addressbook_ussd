# frozen_string_literal: true

module Pagination
  ITEMS_PER_PAGE = 5

  # Paginates any array for display across multiple USSD screens.
  #
  # Usage in a page:
  #   include Pagination
  #   paged = paginate(@data[:items], page: current_page)
  #   paged.each_with_index { |item, i| ... }
  #   nav_options(paged)  # appends "01. Next  02. Back" as needed
  #
  def paginate(collection, page: 1, per_page: ITEMS_PER_PAGE)
    total_pages   = [(collection.size / per_page.to_f).ceil, 1].max
    current_page  = [[page.to_i, 1].max, total_pages].min
    start_index   = (current_page - 1) * per_page
    items         = collection[start_index, per_page] || []

    PagedResult.new(items, current_page, total_pages)
  end

  # Builds the navigation footer shown at the bottom of a paginated screen.
  #   "01. Next  02. Previous" / "01. Next" / "02. Previous"
  def nav_options(paged)
    parts = []
    parts << "#{NEXT}. Next"     if paged.next_page
    parts << "#{PREV}. Previous" if paged.previous_page
    parts.any? ? "\n#{parts.join('  ')}" : ''
  end

  # Resolves which page number to show based on the user's nav input.
  # Call this inside process_response before re-rendering.
  #
  #   page = resolve_page(@ussd_body, current: @tracker[:page].to_i)
  #   render with page: page
  #
  def resolve_page(input, current:)
    case input
    when NEXT then current + 1
    when PREV then [current - 1, 1].max
    else current
    end
  end

  class PagedResult < Array
    attr_reader :current_page, :total_pages

    def initialize(items, current_page, total_pages)
      super(items)
      @current_page = current_page
      @total_pages  = total_pages
    end

    def next_page
      @current_page < @total_pages ? @current_page + 1 : nil
    end

    def previous_page
      @current_page > 1 ? @current_page - 1 : nil
    end

    def last_page?
      @current_page >= @total_pages
    end
  end
end
