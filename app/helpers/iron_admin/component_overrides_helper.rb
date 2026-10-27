# frozen_string_literal: true

module IronAdmin
  # Builds the override components the engine's views render (see
  # {IronAdmin::Configuration::Components}). Each method returns nil when the
  # slot has no override, and the view then renders its built-in markup.
  module ComponentOverridesHelper
    # @param slot [Symbol] A layout slot (+:shell+, +:navbar+, +:sidebar+ or +:flash+)
    # @return [ViewComponent::Base] The override, or the built-in component
    # @example Render the flash slot in a custom shell
    #   = render helpers.iron_admin_component(:flash, flash: helpers.flash, current_user: @current_user)
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

    # @return [ViewComponent::Base, nil] The index page's search override
    def iron_admin_search_component(resource_class, scope:)
      iron_admin_resource_component(:search, resource_class) do
        { form_url: resources_path(resource_class.resource_name), value: params[:q],
          placeholder: I18n.t("iron_admin.resources.index.search_placeholder"),
          hidden_params: iron_admin_search_hidden_params(scope), }
      end
    end

    # @param filters [Array<Hash>] The visible filters
    # @return [ViewComponent::Base, nil] The index page's filter bar override
    def iron_admin_filter_bar_component(resource_class, filters:, scope:)
      iron_admin_resource_component(:filter_bar, resource_class) do
        { filters: filters, form_url: resources_path(resource_class.resource_name), scope: scope,
          query: params[:q], active_count: filters.count { |filter| iron_admin_active_filter?(filter) },
          current_sort: iron_admin_index_state["sort"], current_direction: iron_admin_index_state["direction"], }
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

    # Index path sorted by +field_name+, keeping the scope, search and filters.
    # A new sort starts back at the first page.
    #
    # @return [String]
    def iron_admin_sort_path(resource_class, scope, field_name, direction)
      resources_path(resource_class.resource_name, **iron_admin_unsorted_state(scope), sort: field_name, direction: direction)
    end

    # The hidden fields a search submit adds to keep the scope, active filters and sort.
    #
    # @return [Hash{String => String}] Field name => value
    def iron_admin_search_hidden_params(scope)
      iron_admin_hidden_params({ "scope" => scope }.merge(iron_admin_index_state.slice("sort", "direction", "filters")))
    end

    # Flattens nested params into hidden field names, such as "filters[title][op]".
    #
    # @param state [Hash] Params shaped like {IronAdmin::Concerns::IndexStatePreservable#iron_admin_index_state}
    # @return [Hash{String => String}] Field name => value
    def iron_admin_hidden_params(state, prefix = nil)
      state.each_with_object({}) do |(key, value), fields|
        name = prefix ? "#{prefix}[#{key}]" : key.to_s
        if value.is_a?(Hash)
          fields.merge!(iron_admin_hidden_params(value, name))
        else
          fields[name] = value
        end
      end
    end

    private

    # Builds the arguments (the block) only when the slot has an override.
    def iron_admin_resource_component(slot, resource_class)
      component_class = IronAdmin.configuration.components.resolve(slot, resource_class: resource_class)
      return unless component_class

      arguments = { resource_class: resource_class, current_user: iron_admin_current_user, **yield }
      IronAdmin::Configuration::Components.instantiate(component_class, arguments)
    end

    # Index URL keeping the scope, query and filters, ready for "&sort=..." to be appended.
    def iron_admin_sort_base_url(resource_class, scope)
      url = resources_path(resource_class.resource_name, **iron_admin_unsorted_state(scope))
      url.include?("?") ? url : "#{url}?"
    end

    # The index state without its sort and page, with +scope+ as the scope.
    def iron_admin_unsorted_state(scope)
      iron_admin_index_state.except("sort", "direction", "page").merge("scope" => scope).compact.symbolize_keys
    end
  end
end
