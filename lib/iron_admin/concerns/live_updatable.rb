# frozen_string_literal: true

module IronAdmin
  module Concerns
    module LiveUpdatable
      extend ActiveSupport::Concern

      included do
        class_attribute :live_index_enabled, default: false
        class_attribute :live_show_enabled, default: false
      end

      class_methods do
        def live_index(value = nil, enabled: true)
          self.live_index_enabled = value.nil? ? enabled : value
        end

        def live_show(value = nil, enabled: true)
          self.live_show_enabled = value.nil? ? enabled : value
        end

        def live_index_enabled?
          !!live_index_enabled
        end

        def live_show_enabled?
          !!live_show_enabled
        end

        def live_stream_name(scope, record_id = nil)
          parts = ["resources", resource_name, scope]
          parts << record_id if record_id
          parts.join(":")
        end
      end
    end
  end
end
