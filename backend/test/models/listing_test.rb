require "test_helper"

class ListingTest < ActiveSupport::TestCase
  test "public_attributes is exactly the allowlist" do
    attrs = listings(:jimny).public_attributes

    assert_equal Listing::PUBLIC_ATTRIBUTES.sort, attrs.keys.sort
    %w[sold_price sold_at source source_url source_id].each { |key| refute_includes attrs.keys, key }
  end

  test "image_urls round-trips as an array" do
    assert_equal [ "https://example.com/jimny/1.jpg", "https://example.com/jimny/2.jpg" ], listings(:jimny).image_urls
  end

  test "reveal_attributes carries the price" do
    assert_equal 10_000, listings(:jimny).reveal_attributes["sold_price"]
  end
end
