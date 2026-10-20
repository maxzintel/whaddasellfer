class Game < ApplicationRecord
  has_secure_token :token

  belongs_to :puzzle
  has_many :rounds, -> { order(:position) }, dependent: :destroy

  normalizes :player_name, with: ->(name) { name.squish }

  validates :player_name, presence: true, length: { maximum: 30 }
  validates :score, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  def completed?
    completed_at.present?
  end
end
