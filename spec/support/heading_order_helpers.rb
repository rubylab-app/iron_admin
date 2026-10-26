# frozen_string_literal: true

# Finds headings that skip a level, as axe-core's heading-order rule does:
# each heading may be at most one level below the heading before it.
#
# @example
#   expect(heading_order_problems(response.body)).to be_empty
module HeadingOrderHelpers
  # @param html [String, Nokogiri::XML::Node] Rendered HTML
  # @return [Array<String>] One message per heading that skips a level
  def heading_order_problems(html)
    document = html.is_a?(String) ? Nokogiri::HTML5(html) : html
    previous = nil
    document.css("h1, h2, h3, h4, h5, h6").filter_map do |heading|
      level = heading.name.delete_prefix("h").to_i
      problem = "<#{heading.name}> #{heading.text.squish.inspect} follows <h#{previous}>" if previous && level > previous + 1
      previous = level
      problem
    end
  end
end

RSpec.configure do |config|
  config.include HeadingOrderHelpers
end
