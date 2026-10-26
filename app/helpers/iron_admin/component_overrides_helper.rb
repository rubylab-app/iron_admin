# frozen_string_literal: true

module IronAdmin
  # Builds the override components the engine's views render (see
  # {IronAdmin::Configuration::Components}). Each method returns nil when the
  # slot has no override, and the view then renders its built-in markup.
  module ComponentOverridesHelper
    # @param slot [Symbol] A layout slot (+:shell+, +:navbar+ or +:sidebar+)
    # @return [ViewComponent::Base] The override, or the built-in component
    def iron_admin_component(slot, **arguments)
      IronAdmin.configuration.components.build(slot, **arguments)
    end

    # @return [ViewComponent::Base, nil] The index page's table override
    def iron_admin_table_component(resource_class, records:, fields:, scope:)
      iron_admin_resource_component(:table, resource_class) do
        { records: records, fields: fields, current_sort: params[:sort], current_direction: params[:direction],
          scope: scope, query: params[:q], base_url: iron_admin_sort_base_url(resource_class, scope), }
      end
    end

    # @param filters [Array<Hash>] The visible filters
    # @return [ViewComponent::Base, nil] The index page's search override
    def iron_admin_search_component(resource_class, filters:, scope:)
      iron_admin_resource_component(:search, resource_class) do
        { form_url: resources_path(resource_class.resource_name), value: params[:q],
          placeholder: I18n.t("iron_admin.resources.index.search_placeholder"),
          hidden_params: iron_admin_search_hidden_params(filters, scope), }
      end
    end

    # @param filters [Array<Hash>] The visible filters
    # @return [ViewComponent::Base, nil] The index page's filter bar override
    def iron_admin_filter_bar_component(resource_class, filters:, scope:)
      iron_admin_resource_component(:filter_bar, resource_class) do
        { filters: filters, form_url: resources_path(resource_class.resource_name), scope: scope,
          query: params[:q], active_count: filters.count { |filter| iron_admin_active_filter?(filter) }, }
      end
    end

    # @param url [String] Where the form submits
    # @return [ViewComponent::Base, nil] The new and edit form override
    def iron_admin_form_component(resource_class, record:, fields:, url:)
      iron_admin_resource_component(:form, resource_class) { { record: record, fields: fields, url: url } }
    end

    # @return [Array<Symbol>] Field types whose form input is overridden
    def iron_admin_field_component_types
      IronAdmin.configuration.components.field_types
    end

    # @param form [ActionView::Helpers::FormBuilder] The record's form builder
    # @param field [IronAdmin::Field] The field to render an input for
    # @return [ViewComponent::Base, nil] The field type's input override
    def iron_admin_field_component(form, field)
      IronAdmin.configuration.components.build_field(field, form: form, record: form.object)
    end

    private

    # Builds the arguments (the block) only when the slot has an override.
    def iron_admin_resource_component(slot, resource_class)
      component_class = IronAdmin.configuration.components.resolve(slot, resource_class: resource_class)
      return unless component_class

      arguments = { resource_class: resource_class, current_user: iron_admin_current_user, **yield }
      IronAdmin::Configuration::Components.instantiate(component_class, arguments)
    end

    # Index URL keeping the scope and query, ready for "&sort=..." to be appended.
    def iron_admin_sort_base_url(resource_class, scope)
      url = resources_path(resource_class.resource_name, scope: scope, q: params[:q].presence)
      url.include?("?") ? url : "#{url}?"
    end

    # The hidden fields the built-in search form adds to keep the scope and active filters.
    def iron_admin_search_hidden_params(filters, scope)
      filters.each_with_object({ "scope" => scope }) do |filter, hidden|
        name = filter[:name].to_s
        value = iron_admin_filter_param(name)
        if filter[:type].in?(%i[string number])
          next unless value.is_a?(ActionController::Parameters) && value["value"].present?

          %w[op value value_2].each { |key| hidden["filters[#{name}][#{key}]"] = value[key] if value[key].present? }
        elsif filter[:type] == :date_range
          %w[from to].each do |suffix|
            range_value = iron_admin_filter_param("#{name}_#{suffix}")
            hidden["filters[#{name}_#{suffix}]"] = range_value if range_value.present?
          end
        elsif value.present?
          hidden["filters[#{name}]"] = value
        end
      end
    end
  end
end
