require "test_helper"

class NetworkGamesControllerTest < ActionDispatch::IntegrationTest
  test "should get join" do
    get network_games_join_url
    assert_response :success
  end

  test "should get waiting" do
    get network_games_waiting_url
    assert_response :success
  end
end
