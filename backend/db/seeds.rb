# Loads ../data/listings.csv into listings. Idempotent: re-running updates rows in place, keyed on source_id.
require "csv"

path = Rails.root.join("..", "data", "listings.csv")

rows = CSV.foreach(path, headers: true).map do |row|
  {
    source_id: row["source_id"],
    year: Integer(row["year"]),
    make: row["make"],
    model: row["model"],
    title: row["title"],
    mileage: row["mileage"].presence&.to_i,
    transmission: row["transmission"].presence,
    body_style: row["body_style"].presence,
    exterior_color: row["exterior_color"].presence,
    interior_color: row["interior_color"].presence,
    title_status: row["title_status"].presence,
    highlights: row["highlights"].presence,
    image_urls: JSON.parse(row["image_urls"]),
    sold_price: Integer(row["sold_price"]),
    sold_at: Time.zone.parse(row["sold_at"]),
    source: row["source"],
    source_url: row["source_url"]
  }
end

Listing.upsert_all(rows, unique_by: :source_id)
puts "Seeded #{rows.size} listings (#{Listing.count} total)"
