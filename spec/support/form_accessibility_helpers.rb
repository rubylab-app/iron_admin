# frozen_string_literal: true

# Finds labels that point at nothing and form controls a screen reader cannot
# name. A name comes from a `label[for]`, a wrapping label, `aria-label` or
# `aria-labelledby`; a placeholder or title does not count.
#
# @example
#   expect(form_accessibility_problems(response.body)).to be_empty
module FormAccessibilityHelpers
  # Input types named by their own value, or never shown.
  UNNAMED_INPUT_TYPES = %w[hidden submit reset button image].freeze

  # Elements a `label[for]` can name. Trix names `<trix-editor>` from its labels.
  LABELABLE = "input:not([type=hidden]), select, textarea, button, meter, output, progress, trix-editor"

  # Option and script text is not part of a label's name.
  LABEL_TEXT = ".//text()[not(ancestor::select) and not(ancestor::textarea) and not(ancestor::script)]"

  # @param html [String, Nokogiri::XML::Node] Rendered HTML
  # @return [Array<String>] One message per broken label or unnamed control
  def form_accessibility_problems(html)
    document = html.is_a?(String) ? Nokogiri::HTML5(html) : html
    broken_label_targets(document) + orphan_labels(document) + unnamed_controls(document)
  end

  private

  def broken_label_targets(document)
    document.css("label[for]").filter_map do |label|
      targets = elements_with_id(document, label[:for])
      next if targets.one? && targets.first.matches?(LABELABLE)

      "label #{label_text(label).inspect} for=#{label[:for].inspect}: #{target_problem(targets)}"
    end
  end

  def target_problem(targets)
    return "no element has that id" if targets.empty?
    return "#{targets.size} elements have that id" if targets.size > 1

    "<#{targets.first.name}> is not a labelable control"
  end

  def orphan_labels(document)
    document.css("label:not([for])").filter_map do |label|
      next if label.at_css(LABELABLE)

      "label #{label_text(label).inspect} has no for and wraps no control"
    end
  end

  def unnamed_controls(document)
    document.css("input, select, textarea").filter_map do |control|
      next if control.name == "input" && UNNAMED_INPUT_TYPES.include?(control[:type].to_s.downcase)
      next if accessible_name?(document, control)

      "#{control.name}#{describe_control(control)} has no accessible name"
    end
  end

  def accessible_name?(document, control)
    control[:"aria-label"].to_s.strip.present? ||
      labelled_by?(document, control) ||
      labelled_for?(document, control) ||
      wrapped_by_label?(control)
  end

  def labelled_by?(document, control)
    ids = control[:"aria-labelledby"].to_s.split
    return false if ids.empty?

    labels = ids.map { |id| elements_with_id(document, id).first }
    labels.all? && labels.map { |label| label_text(label) }.join.strip.present?
  end

  def labelled_for?(document, control)
    return false if control[:id].blank?

    document.css("label[for]").any? { |label| label[:for] == control[:id] && label_text(label).present? }
  end

  def wrapped_by_label?(control)
    label = control.ancestors("label").first
    label.present? && (label[:for].blank? || label[:for] == control[:id]) && label_text(label).present?
  end

  # Compared as strings: a CSS selector would need escaping for ids such as `record[user_id]`.
  def elements_with_id(document, id)
    document.xpath(".//*[@id=$id]", {}, { "id" => id })
  end

  def label_text(label)
    label.xpath(LABEL_TEXT).map(&:text).join(" ").squish
  end

  def describe_control(control)
    %i[type name id placeholder].filter_map { |attr| "[#{attr}=#{control[attr].inspect}]" if control[attr] }.join
  end
end

RSpec.configure do |config|
  config.include FormAccessibilityHelpers
end
