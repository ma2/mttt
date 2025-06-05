require "test_helper"

class NetworkGamesControllerTest < ActionDispatch::IntegrationTest
  test "should get join" do
    get network_games_join_url
    assert_response :success
  end

  test "should get waiting" do
    network_game = network_games(:two)  # waiting状態のnetwork_gameを使用
    get network_games_waiting_url(network_game_id: network_game.id)
    assert_response :success
  end
end
