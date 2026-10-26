# frozen_string_literal: true

module IronAdmin
  module Concerns
    # Sends the user back to an index page that exists, with its scope, search,
    # filters and sort. Pagy renders a page past the last one as an empty list
    # with no pagination, as if the list itself were empty.
    module IndexReturnable
      extend ActiveSupport::Concern

      private

      # Redirects an index request whose page is past the last page (a stale
      # link, or a page a bulk action emptied) to the last page.
      #
      # @return [void]
      def redirect_to_last_page
        redirect_to resources_path(@resource_class.resource_name, **iron_admin_index_state.symbolize_keys,
                                                                  page: @pagy.last)
      end

      # Back to the index the bulk action was run from.
      #
      # @param type [Symbol] The flash key
      # @param message [String] The flash message
      # @param state [Hash] The index state to return to
      # @return [void]
      def redirect_bulk(type, message, state: iron_admin_index_state)
        redirect_to resources_path(@resource_class.resource_name, **state.symbolize_keys), type => message
      end

      # The index state after a bulk action, its page capped at the list's new
      # last page. Best effort: a failing count must not report a finished
      # action as failed.
      #
      # @return [Hash] The index state with "page" capped
      def bulk_return_state
        state = iron_admin_index_state
        return state unless state["page"]

        last_page = pagy(collection_scope, limit: IronAdmin.configuration.per_page).first.last
        state["page"].to_i > last_page ? state.merge("page" => last_page.to_s) : state
      rescue StandardError => e
        log_iron_admin_error(e)
        state
      end
    end
  end
end
