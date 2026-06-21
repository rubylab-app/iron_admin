# frozen_string_literal: true

module IronAdmin
  module Live
    class PollCache
      def initialize
        @mutex = Mutex.new
        @streams = Hash.new { |hash, key| hash[key] = [] }
      end

      def push(stream, payload)
        @mutex.synchronize do
          @streams[stream.to_s] << payload.to_s
        end
      end

      def fetch(stream)
        @mutex.synchronize do
          @streams.delete(stream.to_s) || []
        end
      end

      def clear!
        @mutex.synchronize { @streams.clear }
      end
    end
  end
end
