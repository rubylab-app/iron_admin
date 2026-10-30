class HomeController < ApplicationController
  def index
    @email = Current.user.email_address
  end
end
