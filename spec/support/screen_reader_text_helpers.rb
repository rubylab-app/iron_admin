# frozen_string_literal: true

# Tailwind's `sr-only` is `position: absolute`. Without a positioned ancestor in
# its table cell, a wide table's `overflow-x-auto` wrapper does not clip it and
# the whole page scrolls sideways.
module ScreenReaderTextHelpers
  POSITIONED_CLASSES = %w[relative absolute fixed sticky].freeze
  TABLE_CELLS = %w[td th].freeze

  # @param document [Nokogiri::XML::Node] Rendered HTML
  # @return [Nokogiri::XML::NodeSet] `sr-only` elements inside a table cell
  def sr_only_in_table_cells(document)
    document.css("td .sr-only, th .sr-only")
  end

  # @param document [Nokogiri::XML::Node] Rendered HTML
  # @return [Array<String>] Markup of the `sr-only` elements with no positioned ancestor inside their cell
  def unpositioned_sr_only_in_table_cells(document)
    sr_only_in_table_cells(document).reject { |element| positioned_within_cell?(element) }.map(&:to_html)
  end

  private

  def positioned_within_cell?(element)
    element.ancestors.each do |node|
      return true if node.element? && node[:class].to_s.split.intersect?(POSITIONED_CLASSES)
      return false if TABLE_CELLS.include?(node.name)
    end
    false
  end
end

RSpec.configure do |config|
  config.include ScreenReaderTextHelpers
end
