# frozen_string_literal: true

module IronAdmin
  # A custom navigation entry contributed to the admin sidebar.
  #
  # Unlike resource- and tool-derived menu entries (which are inferred from
  # registered {Resource}/{Tool} classes), a MenuItem is an arbitrary link.
  # Plugins use these to surface external pages, custom-mounted engines, or
  # standalone report views in the sidebar without defining a full resource.
  #
  # @example
  #   IronAdmin::MenuItem.new(
  #     label: "Reports",
  #     path: "/admin/reports",
  #     icon: "chart-bar",
  #     group: "Analytics",
  #     priority: 50
  #   )
  #
  # @see IronAdmin::MenuRegistry
  class MenuItem
    # @return [String] Human-readable label rendered in the sidebar
    attr_reader :label

    # @return [String] URL or path the entry links to
    attr_reader :path

    # @return [String, nil] Optional heroicon name shown beside the label
    attr_reader :icon

    # @return [String] Sidebar group heading (defaults to "Plugins")
    attr_reader :group

    # @return [Integer] Sort weight within the group (lower shows first)
    attr_reader :priority

    # @param label [String] Human-readable label
    # @param path [String] URL or path to link to
    # @param icon [String, nil] Optional heroicon name
    # @param group [String] Sidebar group heading
    # @param priority [Integer] Sort weight within the group
    # @raise [ArgumentError] If label or path is blank
    def initialize(label:, path:, icon: nil, group: "Plugins", priority: 999)
      raise ArgumentError, "MenuItem label can't be blank" if label.nil? || label.to_s.strip.empty?
      raise ArgumentError, "MenuItem path can't be blank" if path.nil? || path.to_s.strip.empty?

      @label = label.to_s
      @path = path.to_s
      @icon = icon
      @group = (group || "Plugins").to_s
      @priority = priority || 999
    end

    # A stable identity key used to de-duplicate menu items across repeated
    # activation passes (e.g. Rails `to_prepare` re-runs in development).
    #
    # @return [String]
    def key
      "#{group}::#{label}::#{path}"
    end
  end
end
