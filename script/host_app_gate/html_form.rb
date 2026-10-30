require "uri"
require_relative "failure"
require_relative "gate"

# A rendered form, submitted the way a browser would submit it.
class HostAppGateHtmlForm
  def self.record_form(document)
    node = document.css("form").find { |form| form.at_css("[name='record[name]']") }
    raise HostAppGateFailure, "page has no record form" unless node

    new(node)
  end

  def self.delete_form(document)
    node = document.css("form").find { |form| form.at_css("input[name='_method'][value='delete']") }
    raise HostAppGateFailure, "show page has no delete form" unless node

    new(node)
  end

  def self.index_search(document)
    node = document.css("form").find { |form| index_search_form?(form) }
    raise HostAppGateFailure, "index has no search form outside the navbar" unless node

    new(node)
  end

  # The archive button inside #bulk-actions-form. POST is the default method
  # when the button sets no formmethod. The payload is the form's hidden
  # fields, including authenticity_token, plus the chosen ids.
  def self.bulk_archive(document, ids)
    form = document.at_css("#bulk-actions-form")
    raise HostAppGateFailure, "index has no #bulk-actions-form" unless form

    button = archive_button(form)
    [archive_path(button), new(form).hidden_payload("ids" => ids)]
  end

  def self.index_search_form?(form)
    return false if navbar_form?(form)
    return false unless form_method(form) == "get"
    return false unless request_path(form["action"]) == HostAppGate::PRODUCTS_PATH

    query_input(form)
  end

  def self.navbar_form?(form)
    form.ancestors.any? do |node|
      node.name == "header" || node["data-controller"].to_s.split.include?("cp-search-shortcut")
    end
  end

  def self.archive_button(form)
    button = form.css("[formaction]").find { |node| node["formaction"].to_s.include?("bulk_actions/archive") }
    raise HostAppGateFailure, "#bulk-actions-form has no archive button" unless button

    button
  end

  def self.archive_path(button)
    path = request_path(button["formaction"])
    expected = "#{HostAppGate::PRODUCTS_PATH}/bulk_actions/archive"
    raise HostAppGateFailure, "archive formaction is #{path}" unless path == expected

    method = button["formmethod"].to_s
    method = "post" if method.empty?
    raise HostAppGateFailure, "archive method is #{method}" unless method.casecmp("post").zero?

    path
  end

  def self.form_method(form)
    method = form["method"].to_s
    method = "get" if method.empty?
    method.downcase
  end

  def self.request_path(raw)
    return if raw.blank?

    URI.parse(raw).path
  rescue URI::InvalidURIError
    nil
  end

  def self.query_input(form)
    form.css("input").find do |input|
      type = input["type"].to_s
      type = "text" if type.empty?
      %w[text search].include?(type) && input["name"].present?
    end
  end

  def initialize(form)
    @form = form
  end

  def path
    found = self.class.request_path(@form["action"])
    raise HostAppGateFailure, "form has no action" if found.blank?

    found
  end

  def verb
    self.class.form_method(@form).to_sym
  end

  def method_override
    hidden = @form.at_css("input[name='_method']")
    return if hidden.nil?

    hidden["value"].to_s
  end

  def query_name
    input = self.class.query_input(@form)
    raise HostAppGateFailure, "search form has no text input" unless input

    input["name"]
  end

  def payload(overrides = {})
    fields = {}
    @form.css("input, select, textarea").each do |field|
      name = field["name"]
      next if name.blank?

      value = field_value(field)
      next if value.nil?

      assign(fields, name, value)
    end
    apply_overrides(fields, overrides)
    fields
  end

  def hidden_payload(overrides = {})
    fields = {}
    @form.css("input[type='hidden']").each do |field|
      name = field["name"]
      next if name.blank?

      assign(fields, name, field["value"].to_s)
    end
    apply_overrides(fields, overrides)
    fields
  end

  private

  def apply_overrides(fields, overrides)
    overrides.each { |name, value| assign(fields, name, value) }
  end

  def field_value(field)
    case field.name
    when "textarea"
      field.text
    when "select"
      select_value(field)
    else
      input_value(field)
    end
  end

  # A single select with nothing selected submits its first enabled option.
  # That is what a browser sends, including a blank placeholder.
  def select_value(field)
    chosen = field.at_css("option[selected]")
    chosen = first_enabled_option(field) if chosen.nil? && field["multiple"].nil?
    return if chosen.nil?

    chosen["value"].to_s
  end

  def first_enabled_option(field)
    field.css("option").find { |option| option["disabled"].nil? }
  end

  def input_value(field)
    type = field["type"].to_s
    return if %w[submit button file].include?(type)
    return if type == "checkbox" && field["checked"].nil?

    field["value"].to_s
  end

  def assign(fields, name, value)
    unless name.include?("[")
      fields[name] = value
      return
    end

    raise HostAppGateFailure, "field #{name} is nested more than once" if name.count("[") > 1

    head, rest = name.split("[", 2)
    fields[head] ||= {}
    fields[head][rest.delete_suffix("]")] = value
  end
end
