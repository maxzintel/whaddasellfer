module Api
  # Local testing tools for the frontend's dev toolbar. The route only exists in
  # development and test; this check is a second lock in case it ever gets drawn elsewhere.
  class DevController < ApplicationController
    before_action { head :not_found unless Rails.env.local? }

    def reset_today
      date = Time.zone.today
      render json: { puzzle_date: date.iso8601, games_deleted: Puzzle.reset_day!(date) }
    end
  end
end
