class PagesController < ApplicationController

  skip_before_filter :authenticate_user!, only: :home

  def test
  end

  def home
    set_tab :home
    @user_started_responses = user_signed_in? ? current_user.responses : nil
    else


  end
end
