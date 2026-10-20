module Api
  class LeaderboardsController < ApplicationController
    def show
      render json: LeaderboardSerializer.new(date: Time.zone.today, token: params[:token]).as_json
    end
  end
end
