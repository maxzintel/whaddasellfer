# v1 formula: max(0, round(1000 * (1 - 2 * |guess - actual| / actual))).
# Rational keeps the math exact so .round never sees a float like 499.99999.
module Scoring
  MAX_POINTS = 1000

  def self.points(guess:, actual:)
    raise ArgumentError, "actual must be positive" unless actual.is_a?(Integer) && actual.positive?
    raise ArgumentError, "guess must be positive" unless guess.is_a?(Integer) && guess.positive?

    [ 0, (MAX_POINTS * (1 - 2 * Rational((guess - actual).abs, actual))).round ].max
  end
end
