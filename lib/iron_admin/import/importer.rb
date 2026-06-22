# frozen_string_literal: true

module IronAdmin
  module Import
    class Importer
      PARSERS = {
        csv: Parser::Csv,
        json: Parser::Json,
      }.freeze

      def initialize(resource_class, file:, format:, context: nil)
        @resource_class = resource_class
        @file = file
        @format = format.to_sym
        @context = context
        @type_caster = TypeCaster.new
      end

      def preview(limit: nil)
        raw_rows = parse_rows
        headers = headers_for(raw_rows)
        mapping = mapper.map_headers(headers)
        preview_limit = limit || import_options.fetch(:preview_rows, 20)
        rows = raw_rows.first(preview_limit).each_with_index.map do |raw_row, index|
          build_row(raw_row, index + 2, mapping)
        end

        ImportPreview.new(
          total_rows: raw_rows.size,
          headers: headers,
          mapping: mapping,
          rows: rows,
          errors: rows.flat_map(&:errors)
        )
      end

      def execute!
        raw_rows = parse_rows
        enforce_row_limit!(raw_rows)
        mapping = mapper.map_headers(headers_for(raw_rows))
        result_state = empty_result_state

        adapter.transaction do
          raw_rows.each_with_index do |raw_row, index|
            import_row(raw_row, index + 2, mapping, result_state)
          end
        end

        ImportResult.new(
          created_count: result_state[:created_count],
          updated_count: result_state[:updated_count],
          failed_count: result_state[:errors].size,
          errors: result_state[:errors],
          rows: result_state[:rows]
        )
      end

      private

      def adapter
        @resource_class.adapter
      end

      def import_options
        @resource_class.import_options_hash
      end

      def mapper
        ColumnMapper.new(@resource_class, current_user: current_user)
      end

      def current_user
        @context.respond_to?(:current_user) ? @context.current_user : nil
      end

      def parse_rows
        parser_class = PARSERS.fetch(@format) { raise ArgumentError, "Unsupported import format: #{@format}" }
        raise ArgumentError, "#{@format} imports are not enabled" unless @resource_class.import_formats.include?(@format)

        parser_class.new(@file).parse
      end

      def headers_for(raw_rows)
        raw_rows.flat_map(&:keys).uniq
      end

      def empty_result_state
        { created_count: 0, updated_count: 0, errors: [], rows: [] }
      end

      def import_row(raw_row, row_number, mapping, result_state)
        row = build_row(raw_row, row_number, mapping, validate_model: false)
        result_state[:rows] << row
        return collect_existing_errors(row, result_state) if row.errors.any?

        record = find_existing_record(row.attributes)
        validation_errors = validate_record(record, row.attributes)
        return add_error_messages(row, validation_errors, result_state) if validation_errors.any?

        persist_errors = persist_row(record, row.attributes)
        return add_error_messages(row, persist_errors, result_state) if persist_errors.any?

        increment_success_count(record, result_state)
      end

      def collect_existing_errors(row, result_state)
        result_state[:errors].concat(row.errors)
      end

      def add_error_messages(row, messages, result_state)
        row.errors.concat(messages.map { |message| Error.new(row_number: row.number, message: message) })
        collect_existing_errors(row, result_state)
      end

      def increment_success_count(record, result_state)
        key = record ? :updated_count : :created_count
        result_state[key] += 1
      end

      def build_row(raw_row, row_number, mapping, validate_model: true)
        attributes = build_attributes(raw_row, mapping)
        attributes = apply_transform(attributes)
        validation_errors = custom_validation_errors(attributes)
        validation_errors += validate_record(nil, attributes) if validate_model
        row_errors = validation_errors.map { |message| Error.new(row_number: row_number, message: message) }

        Row.new(number: row_number, attributes: attributes, errors: row_errors)
      end

      def build_attributes(raw_row, mapping)
        fields = @resource_class.importable_fields(current_user).index_by(&:name)

        mapping.each_with_object({}) do |(header, field_name), attributes|
          field = fields[field_name]
          next unless field

          attributes[field_name] = @type_caster.cast(raw_row[header], field)
        end
      end

      def apply_transform(attributes)
        block = @resource_class.import_transform_block
        return attributes unless block

        transformed = if block.arity >= 2
                        block.call(attributes, @context)
                      else
                        block.call(attributes)
                      end

        transformed || attributes
      end

      def validate_record(record, attributes)
        model_record = record || adapter.build(attributes)
        assign_attributes(model_record, attributes) if record
        return [] unless model_record.respond_to?(:valid?) && !model_record.valid?

        model_record.errors.full_messages
      end

      def custom_validation_errors(attributes)
        block = @resource_class.import_validate_block
        return [] unless block

        result = if block.arity >= 2
                   block.call(attributes, @context)
                 else
                   block.call(attributes)
                 end

        Array(result).compact.map(&:to_s)
      end

      def find_existing_record(attributes)
        keys = @resource_class.import_upsert_key_names
        return nil if keys.empty?

        lookup = attributes.slice(*keys)
        return nil unless lookup.size == keys.size && lookup.values.all?(&:present?)

        return adapter.find_by_keys(lookup) unless IronAdmin.configuration.tenant_scope_block # rubocop:disable Rails/DynamicFindBy

        scoped_existing_record(lookup)
      end

      def scoped_existing_record(lookup)
        scope = adapter.all
        scope = IronAdmin.configuration.tenant_scope_block.call(scope) if IronAdmin.configuration.tenant_scope_block

        lookup.reduce(scope) do |current_scope, (key, value)|
          adapter.filter(current_scope, key, value)
        end.first
      end

      def persist_row(record, attributes)
        if record
          adapter.update_record(record, attributes) ? [] : record_error_messages(record)
        else
          new_record = adapter.create_record(attributes)
          record_error_messages(new_record)
        end
      end

      def record_error_messages(record)
        return [] if !record.respond_to?(:errors) || record.errors.empty?

        record.errors.full_messages
      end

      def assign_attributes(record, attributes)
        if record.respond_to?(:assign_attributes)
          record.assign_attributes(attributes)
        else
          attributes.each do |name, value|
            setter = "#{name}="
            record.public_send(setter, value) if record.respond_to?(setter)
          end
        end
      end

      def enforce_row_limit!(raw_rows)
        max_rows = import_options[:max_rows]
        return unless max_rows && raw_rows.size > max_rows

        raise ArgumentError, "Import contains #{raw_rows.size} rows, exceeding the #{max_rows} row limit"
      end
    end
  end
end
