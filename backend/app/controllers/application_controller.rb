class ApplicationController < ActionController::API
  # Read params exactly as sent. With wrapping on, a body without `guess` would get
  # one invented by the wrapper (GuessesController -> params[:guess] = {...}).
  wrap_parameters false

  rescue_from ActiveRecord::RecordNotFound do |error|
    render_error "#{error.model || "Record"} not found", :not_found
  end

  rescue_from ActiveRecord::RecordInvalid do |error|
    render_error error.record.errors.full_messages.to_sentence, :unprocessable_content
  end

  rescue_from Round::AlreadyGuessed, Round::InvalidGuess, ActionController::ParameterMissing do |error|
    render_error error.message, :unprocessable_content
  end

  private

  def render_error(message, status)
    render json: { error: message }, status:
  end
end
