# frozen_string_literal: true

require "erb"

module IronAdmin
  module Live
    class Broadcaster
      def initialize(cache: IronAdmin::Live.poll_cache)
        @cache = cache
      end

      def broadcast_replace(stream, target:, html:)
        broadcast_action(stream, action: :replace, target: target, html: html)
      end

      def broadcast_prepend(stream, target:, html:)
        broadcast_action(stream, action: :prepend, target: target, html: html)
      end

      def broadcast_remove(stream, target:)
        broadcast_action(stream, action: :remove, target: target)
      end

      private

      def broadcast_action(stream, action:, target:, html: nil)
        @cache.push(stream, turbo_stream(action: action, target: target, html: html))
      end

      def turbo_stream(action:, target:, html: nil)
        action_attr = escape(action)
        target_attr = escape(target)
        return %(<turbo-stream action="#{action_attr}" target="#{target_attr}"></turbo-stream>) if html.nil?

        %(<turbo-stream action="#{action_attr}" target="#{target_attr}"><template>#{html}</template></turbo-stream>)
      end

      def escape(value)
        ERB::Util.html_escape(value.to_s)
      end
    end
  end
end
