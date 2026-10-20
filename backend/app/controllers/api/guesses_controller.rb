module Api
  class GuessesController < ApplicationController
    def create
      game = Game.find_by!(token: params[:game_token])
      game.round_at!(params[:position]).guess!(params[:guess])
      render json: GameSerializer.new(game.reload).as_json
    end
  end
end
