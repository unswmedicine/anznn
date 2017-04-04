class Admin::AdminBaseController < ApplicationController

  before_action :authenticate_user!

end
