# frozen_string_literal: true

module IronAdmin
  class LiveController < ApplicationController
    def show
      return head(:not_found) unless IronAdmin::Live.polling?

      render plain: IronAdmin::Live.poll_cache.fetch(params[:stream]).join,
             content_type: Mime[:turbo_stream]
    end
  end
end
