require "test_helper"

class Api::HelloControllerTest < ActionDispatch::IntegrationTest
  test "returns a greeting as JSON" do
    get "/api/hello"

    assert_response :success
    assert_equal "Hello from Rails", response.parsed_body["message"]
  end
end
