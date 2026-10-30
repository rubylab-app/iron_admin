# frozen_string_literal: true

module IronAdmin
  module Theme
    # Spec plugin that ships one theme. Theme gems use this namespace.
    class HighContrast < IronAdmin::Plugin
      plugin_name "iron_admin-theme-high_contrast"

      setup do |admin|
        admin.theme(:high_contrast, label: "High Contrast") do |theme|
          theme.btn_primary = "plugin-theme-primary"
        end
      end
    end
  end
end
