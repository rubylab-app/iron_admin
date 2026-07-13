# frozen_string_literal: true

module IronAdmin
  # Registry of custom sidebar {MenuItem}s contributed outside the
  # resource/tool convention — primarily by plugins.
  #
  # Items are de-duplicated by their {MenuItem#key}, so re-activating a
  # plugin (as happens on every Rails `to_prepare` in development) does not
  # produce duplicate sidebar entries.
  #
  # @see IronAdmin::MenuItem
  # @see IronAdmin::PluginRegistry
  class MenuRegistry
    class << self
      # Adds a menu item to the registry (idempotent by {MenuItem#key}).
      #
      # @param menu_item [IronAdmin::MenuItem] The item to add
      # @return [IronAdmin::MenuItem] The registered item
      def register(menu_item)
        items[menu_item.key] = menu_item
      end

      # @return [Array<IronAdmin::MenuItem>] All registered items
      def all
        items.values
      end

      # Returns items grouped by their sidebar group heading.
      #
      # @return [Hash{String => Array<IronAdmin::MenuItem>}]
      def grouped
        all.group_by(&:group)
      end

      # Returns items sorted by priority (ascending).
      #
      # @return [Array<IronAdmin::MenuItem>]
      def sorted
        all.sort_by(&:priority)
      end

      # Clears all registered menu items.
      #
      # @api private
      # @return [void]
      def reset!
        @items = {}
      end

      private

      def items
        @items ||= {}
      end
    end
  end
end
