# frozen_string_literal: true

module IronAdmin
  module Live
    class << self
      attr_writer :poll_cache

      def enabled?
        IronAdmin.configuration.live_updates != :disabled
      end

      def polling?
        IronAdmin.configuration.live_updates == :polling
      end

      def poll_cache
        @poll_cache ||= PollCache.new
      end

      def broadcaster
        Broadcaster.new(cache: poll_cache)
      end

      def reset!
        @poll_cache = PollCache.new
      end
    end
  end
end
