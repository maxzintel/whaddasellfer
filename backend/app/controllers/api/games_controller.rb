module Api
  class GamesController < ApplicationController
    def create
      game = Game.start!(player_name: params[:player_name])
      render json: GameSerializer.new(game).as_json, status: :created
    end

    def show
      render json: GameSerializer.new(Game.find_by!(token: params[:token])).as_json
    end
  end
end
