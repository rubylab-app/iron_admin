# frozen_string_literal: true

module IronAdmin
  module Concerns
    module Importable
      extend ActiveSupport::Concern

      module ImportDsl
        def imports(*formats)
          self.import_formats = formats.flatten.map(&:to_sym)
        end

        def import_enabled?
          import_formats.any?
        end

        def import_fields(*fields)
          self.import_field_names = fields.map(&:to_sym)
        end

        def import_upsert_key(*fields)
          self.import_upsert_key_names = fields.map(&:to_sym)
        end

        def import_transform(&block)
          self.import_transform_block = block
        end

        def import_validate(&block)
          self.import_validate_block = block
        end

        def import_options(**options)
          self.import_options_hash = import_options_hash.merge(options)
        end

        def importable_fields(current_user = nil)
          import_base_fields
            .select { |field| field.visible?(current_user) && !field.readonly?(current_user) }
            .reject { |field| import_excluded_field_type?(field.type) }
        end

        private

        def import_base_fields
          return resolved_fields.select { |field| field.name.in?(import_field_names) } if import_field_names

          resolved_fields.reject { |field| field.name.in?(%i[id created_at updated_at]) }
        end

        def import_excluded_field_type?(field_type)
          field_type.in?(
            %i[
              belongs_to
              polymorphic_belongs_to
              has_many
              has_one
              has_and_belongs_to_many
              file
              files
              rich_text
            ]
          )
        end
      end

      included do
        class_attribute :import_formats, default: []
        class_attribute :import_field_names, default: nil
        class_attribute :import_upsert_key_names, default: []
        class_attribute :import_transform_block, default: nil
        class_attribute :import_validate_block, default: nil
        class_attribute :import_options_hash, default: { max_rows: 5_000, preview_rows: 20 }
      end

      class_methods do
        include ImportDsl
      end
    end
  end
end
