module Api
  class HelloController < ApplicationController
    def show
      render json: { message: "Hello from Rails", ruby: RUBY_VERSION, rails: Rails.version }
    end
  end
end
