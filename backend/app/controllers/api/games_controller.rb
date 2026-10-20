module Api
  class GamesController < ApplicationController
    def create
      # permit drops arrays/hashes, so `{"player_name": ["a"]}` is a blank-name 422, not the name "[\"a\"]".
      game = Game.start!(player_name: params.permit(:player_name)[:player_name])
      render json: GameSerializer.new(game).as_json, status: :created
    end

    def show
      render json: GameSerializer.new(Game.find_by!(token: params[:token])).as_json
    end
  end
end
