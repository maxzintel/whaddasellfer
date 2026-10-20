class Listing < ApplicationRecord
  # Explicit allowlists. Never serialize a listing any other way: sold_price and
  # source_url (the auction page shows the price) must stay hidden until guessed.
  PUBLIC_ATTRIBUTES = %w[
    id year make model title mileage transmission body_style
    exterior_color interior_color title_status highlights image_urls
  ].freeze
  REVEAL_ATTRIBUTES = %w[sold_price sold_at source source_url].freeze

  has_many :puzzle_listings, dependent: :restrict_with_exception
  has_many :rounds, dependent: :restrict_with_exception

  validates :source_id, presence: true, uniqueness: true
  validates :year, :make, :model, :title, :sold_at, :source, :source_url, presence: true
  validates :sold_price, numericality: { only_integer: true, greater_than: 0 }

  def public_attributes
    attributes.slice(*PUBLIC_ATTRIBUTES)
  end

  def reveal_attributes
    attributes.slice(*REVEAL_ATTRIBUTES)
  end
end
