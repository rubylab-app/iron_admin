# frozen_string_literal: true

module IronAdmin
  # Helper methods for rendering specific field types, all private but the show page's
  # display_show_field_value. Extracted from ApplicationHelper for organization.
  module FieldDisplayHelper # rubocop:disable Metrics/ModuleLength
    # strftime format of datetime values, such as "Oct 25, 2026 at 6:30 PM" (squished, since
    # %l pads one-digit hours), unless a field sets its own +format+. The audit log uses it too.
    # @return [String]
    DATETIME_FORMAT = "%b %d, %Y at %l:%M %p"

    # Displays a field value on a show page: the formatted value, or, when the field is empty, a
    # muted dash with a name for screen readers, so an empty row does not read as a value that
    # did not load. A false value is not empty.
    #
    # @param record [ActiveRecord::Base] The record
    # @param field [IronAdmin::Field] Field configuration
    # @return [String, Object] Formatted value, or the empty value marker
    def display_show_field_value(record, field)
      value = display_field_value(record, field)
      return value if value.equal?(false) || value.present?

      content_tag(:span, class: "relative") do
        content_tag(:span, "\u2014", class: cp_muted_text, "aria-hidden": "true") +
          content_tag(:span, I18n.t("iron_admin.fields.empty_value"), class: "sr-only")
      end
    end

    private

    def display_hidden(_record, _field)
      nil
    end

    def display_radio(record, field)
      value = record.public_send(field.name)
      return if value.blank?

      content_tag(:span, value.to_s.humanize, class: "text-sm #{cp_body_text}")
    end

    def display_code(record, field)
      value = record.public_send(field.name)
      return if value.blank?

      lang = field.options[:language].presence || ""
      content_tag(:pre, class: "overflow-x-auto p-4 text-sm #{t.border_radius} #{t.code_block}") do
        content_tag(:code, value, class: "#{t.code_font} language-#{lang}")
      end
    end

    def display_belongs_to(record, field)
      associated = record.public_send(field.name)
      return if associated.nil?

      display_method = field.options[:display]
      label = display_record_label(associated, display_method)

      resource = IronAdmin::ResourceRegistry.find(associated.class.model_name.plural)
      if resource
        link_to label, iron_admin.resource_path(resource.resource_name, associated),
                class: cp_link
      else
        label
      end
    end

    def display_badge(record, field)
      value = record.public_send(field.name)
      return if value.nil?

      colors = field.options[:colors] || {}
      color = colors[value.to_sym] ||
              IronAdmin.configuration.badge_colors[value.to_s] ||
              IronAdmin.configuration.badge_colors[value] ||
              :gray

      render(IronAdmin::Ui::BadgeComponent.new(text: value.to_s.humanize, color: color))
    end

    def display_password
      content_tag(:span, "\u2022" * 8, class: "tracking-wider #{cp_muted_text}")
    end

    def display_file(record, field)
      return unless record.respond_to?(field.name)

      attachment = record.public_send(field.name)
      return unless attachment.attached?

      if attachment.image?
        image_tag main_app.url_for(attachment), class: "h-16 w-16 object-cover #{t.control_radius}"
      else
        content_tag(:span, class: "inline-flex items-center gap-1.5") do
          heroicon("paper-clip", variant: :mini, options: { class: "h-4 w-4 #{cp_muted_text}" }) +
            content_tag(:span, attachment.filename.to_s, class: cp_link)
        end
      end
    end

    def display_files(record, field)
      return unless record.respond_to?(field.name)

      attachments = record.public_send(field.name)
      return unless attachments.attached?

      content_tag(:div, class: "flex flex-wrap gap-2") do
        safe_join(
          attachments.map do |attachment|
            if attachment.image?
              image_tag main_app.url_for(attachment), class: "h-12 w-12 object-cover #{t.control_radius}"
            else
              content_tag(:span, attachment.filename.to_s, class: "inline-flex items-center px-2 py-0.5 text-xs #{chip_classes}")
            end
          end
        )
      end
    end

    def display_rich_text(record, field)
      content = record.public_send(field.name)
      return if content.blank?

      content_tag(:div, sanitize(content.to_s), class: "trix-content")
    end

    def display_markdown(record, field)
      content = record.public_send(field.name)
      return if content.blank?

      begin
        require "redcarpet"
        renderer = Redcarpet::Render::HTML.new(hard_wrap: true, filter_html: true)
        markdown = Redcarpet::Markdown.new(renderer, autolink: true, tables: true, fenced_code_blocks: true)
        content_tag(:div, markdown.render(content).html_safe, class: "trix-content") # rubocop:disable Rails/OutputSafety
      rescue LoadError
        content_tag(:pre, content, class: "text-sm whitespace-pre-wrap #{cp_body_text}")
      end
    end

    def display_tags(record, field)
      value = record.public_send(field.name)
      return if value.blank?

      tags = value.is_a?(Array) ? value : value.to_s.split(",").map(&:strip)
      return if tags.empty?

      content_tag(:div, class: "flex flex-wrap gap-1") do
        safe_join(
          tags.map do |tag|
            content_tag(:span, tag, class: "inline-flex items-center px-2 py-0.5 text-xs #{chip_classes}")
          end
        )
      end
    end

    def display_url(record, field)
      value = record.public_send(field.name)
      return if value.blank?

      content_tag(:span, class: "inline-flex items-center gap-1") do
        link_to(value, value, target: "_blank", rel: "noopener noreferrer", class: cp_link) +
          heroicon("arrow-top-right-on-square", variant: :mini, options: { class: "h-3.5 w-3.5 #{t.icon_muted}" })
      end
    end

    def display_email(record, field)
      value = record.public_send(field.name)
      return if value.blank?

      link_to(value, "mailto:#{value}", class: cp_link)
    end

    def display_color(record, field)
      value = record.public_send(field.name)
      return if value.blank?

      content_tag(:span, class: "inline-flex items-center gap-2") do
        content_tag(:span, "", class: "inline-block h-5 w-5 #{t.control_radius} #{t.border_width} #{t.card_border}",
                               style: "background-color: #{ERB::Util.html_escape(value)}") +
          content_tag(:code, value, class: "text-xs #{cp_muted_text}")
      end
    end

    def display_currency(record, field)
      value = record.public_send(field.name)
      return if value.nil?

      symbol = field.options[:symbol] || "$"
      precision = field.options[:precision] || 2
      formatted = number_with_delimiter(format("%.#{precision}f", value.to_f))
      content_tag(:span, "#{symbol}#{formatted}", class: "tabular-nums")
    end

    def display_boolean(record, field)
      if record.public_send(field.name)
        boolean_icon("check-circle", t.success_text, I18n.t("iron_admin.fields.boolean_true"))
      else
        boolean_icon("x-circle", cp_muted_text, I18n.t("iron_admin.fields.boolean_false"))
      end
    end

    # The icon SVGs ship with aria-hidden, so screen readers announce the visually hidden label instead.
    # The wrapper is `relative` so the absolutely positioned sr-only text stays inside the table cell;
    # otherwise a wide table's overflow-x-auto does not clip it and the whole page scrolls sideways.
    def boolean_icon(icon, color, label)
      content_tag(:span, class: "relative inline-flex") do
        heroicon(icon, variant: :mini, options: { class: "h-5 w-5 #{color}" }) +
          content_tag(:span, label, class: "sr-only")
      end
    end

    def display_date(record, field)
      value = record.public_send(field.name)
      return if value.nil?

      fmt = field.options[:format] || "%b %d, %Y"
      value.strftime(fmt)
    end

    def display_datetime(record, field)
      value = record.public_send(field.name)
      return if value.nil?

      fmt = field.options[:format] || DATETIME_FORMAT
      value.strftime(fmt).squish
    end

    def allowed_polymorphic_type?(field, type_value)
      Array(field.options[:types]).any? do |type|
        name = type.is_a?(Class) ? type.name : type.to_s
        name == type_value.to_s
      end
    end

    def display_polymorphic_belongs_to(record, field)
      type_value = record.public_send(field.options[:type_column])
      id_value = record.public_send(field.options[:id_column])
      return if type_value.blank? || id_value.blank?

      begin
        return "#{type_value}##{id_value}" unless allowed_polymorphic_type?(field, type_value)

        type_class = type_value.constantize
        associated_resource = IronAdmin::ResourceRegistry.find(type_class.model_name.plural)
        associated = if associated_resource
                       associated_resource.adapter.find_by(id: id_value)
                     else
                       type_class.find_by(id: id_value)
                     end
        return "#{type_value}##{id_value}" unless associated

        resource = IronAdmin::ResourceRegistry.find(associated.class.model_name.plural)
        label = display_record_label(associated)
        type_label = type_value.underscore.humanize

        if resource
          content_tag(:span, class: "inline-flex items-center gap-1.5") do
            content_tag(:span, type_label, class: "text-xs #{cp_muted_text}") +
              link_to(label, iron_admin.resource_path(resource.resource_name, associated), class: cp_link)
          end
        else
          "#{type_label}: #{label}"
        end
      rescue NameError
        "#{type_value}##{id_value}"
      end
    end

    def display_key_value(record, field)
      value = record.public_send(field.name)
      return if value.blank?

      pairs = parse_hash_value(value)
      return if pairs.empty?

      content_tag(:dl, class: "divide-y text-sm #{t.table_border} #{t.control_radius} #{t.border_width} #{t.card_border}") do
        safe_join(pairs.map { |k, v| key_value_pair_row(k, v) })
      end
    end

    def key_value_pair_row(key, value)
      content_tag(:div, class: "flex gap-4 px-3 py-2") do
        content_tag(:dt, key, class: "font-medium w-1/3 #{cp_body_text}") +
          content_tag(:dd, value.to_s, class: "flex-1 #{cp_muted_text}")
      end
    end

    def display_boolean_group(record, field)
      values = parse_array_value(record.public_send(field.name))
      return if values.empty?

      safe_join(values.map { |v| boolean_group_pill(v) })
    end

    def boolean_group_pill(value)
      content_tag(:span, value.to_s.humanize, class: "inline-block px-2 py-0.5 mr-1 mb-1 text-xs #{chip_classes}")
    end

    # Tags, file names and other values shown as chips.
    def chip_classes
      "#{t.badge_shape} #{t.chip}"
    end

    def display_external_image(record, field)
      url = record.public_send(field.name)
      return if url.blank?
      return if url.to_s.match?(/\Ajavascript:/i)

      height = field.options[:height] || "h-32"
      tag.img(
        src: url,
        alt: "",
        class: "#{height} w-auto object-cover #{t.control_radius} #{t.border_width} #{t.card_border}",
        loading: "lazy",
        onerror: "this.style.display='none'"
      )
    end

    def display_progress_bar(record, field)
      value = record.public_send(field.name)
      return if value.nil?

      pct = calculate_progress_percentage(value, field)

      content_tag(:div, class: "flex items-center gap-2") do
        progress_bar_track(pct, field.options[:color]) +
          content_tag(:span, "#{value.to_i}%", class: "text-xs tabular-nums #{cp_muted_text}")
      end
    end

    def display_truncated_index_value(record, field)
      value = record.public_send(field.name)
      return if value.blank?

      display_truncated_text(value.to_s)
    end

    # A long text is cut to INDEX_TRUNCATION_LENGTH, with the whole text in the title.
    def display_truncated_text(text)
      truncated = truncate(text, length: ApplicationHelper::INDEX_TRUNCATION_LENGTH)
      return truncated if text.length <= ApplicationHelper::INDEX_TRUNCATION_LENGTH

      content_tag(:span, truncated, title: text)
    end

    # Index cells show rich text as plain text, truncated like long text fields.
    def display_index_rich_text(record, field)
      text = rich_text_plain_text(record.public_send(field.name))
      display_truncated_text(text) if text.present?
    end

    # The text of rich text HTML on one line: tags dropped, block elements
    # (headings included) kept apart, script and style elements dropped with
    # their content. Loofah ships with Rails through rails-html-sanitizer.
    def rich_text_plain_text(content)
      return "" if content.blank?

      Loofah.fragment(rich_text_html(content)).scrub!(:prune).to_text(encode_special_chars: false).squish
    end

    # A has_rich_text attribute's stored HTML, with each attachment replaced by
    # its plain text (an image's caption or "[filename]", a mention's name) as
    # ActionText's to_plain_text does; any other value as a String.
    def rich_text_html(content)
      body = content.try(:body)
      return content.to_s unless body.respond_to?(:render_attachments)

      body.render_attachments(with_full_attributes: false, &:to_plain_text).to_html
    end

    def display_compact_field_value(record, field)
      case field.type
      when :key_value
        pairs = parse_hash_value(record.public_send(field.name))
        content_tag(:span, "#{pairs.size} keys", class: "text-xs #{cp_muted_text}")
      when :boolean_group
        items = parse_array_value(record.public_send(field.name))
        content_tag(:span, "#{items.size} selected", class: "text-xs #{cp_muted_text}")
      end
    end

    def parse_hash_value(value)
      return value if value.is_a?(Hash)
      return {} if value.nil?

      safe_json_parse_hash(value.to_s)
    end

    def safe_json_parse_hash(value)
      result = JSON.parse(value)
      result.is_a?(Hash) ? result : {}
    rescue JSON::ParserError
      {}
    end

    def parse_array_value(value)
      case value
      when Array then value
      when String then parse_array_string(value)
      else []
      end
    end

    def parse_array_string(value)
      parsed = safe_json_parse_array(value)
      return parsed if parsed

      value.split(",").map(&:strip).compact_blank
    end

    def safe_json_parse_array(value)
      result = JSON.parse(value)
      result.is_a?(Array) ? result : nil
    rescue JSON::ParserError
      nil
    end

    def calculate_progress_percentage(value, field)
      min = (field.options[:min] || 0).to_f
      max = (field.options[:max] || 100).to_f
      ((value.to_f - min) / (max - min) * 100.0).clamp(0.0, 100.0)
    end

    # A +color+ class fills the bar; without one, the theme's chart border color does. Both are
    # rounded with control_radius, like the dashboard's ProgressComponent.
    def progress_bar_track(pct, color)
      width = "width: #{pct.round(1)}%"
      style = color ? width : "#{width}; background-color: #{t.chart_border_color}"
      content_tag(:div, class: "flex-1 h-2 overflow-hidden #{t.control_radius} #{t.progress_track}") do
        content_tag(:div, "", class: "h-2 #{t.control_radius} #{color}".strip, style: style)
      end
    end
  end
end
