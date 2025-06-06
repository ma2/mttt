require "test_helper"

class NetworkGamesControllerTest < ActionDispatch::IntegrationTest
  def setup
    @game = Game.create!(mode: "net")
    @network_game = NetworkGame.create!(
      match_code: "test123",
      game: @game,
      player1_session: "session1",
      status: "waiting"
    )
  end

  test "should get join page" do
    get network_games_join_url
    assert_response :success
    assert_select "h1", "TicTacNine"
    assert_select "h2", "ネット対戦"
  end

  test "create_match should create new network game with valid match code" do
    assert_difference("NetworkGame.count") do
      post network_games_create_match_url, params: { match_code: "newcode123" }
    end

    network_game = NetworkGame.last
    assert_equal "newcode123", network_game.match_code
    assert_equal "waiting", network_game.status
    assert_not_nil session[:player_id]
    assert_equal session[:player_id], network_game.player1_session
    assert_redirected_to network_games_waiting_url(network_game_id: network_game.id)
  end

  test "create_match should match existing waiting game" do
    waiting_game = NetworkGame.create!(
      match_code: "match456",
      game: Game.create!(mode: "net"),
      player1_session: "player1",
      status: "waiting"
    )

    assert_no_difference("NetworkGame.count") do
      post network_games_create_match_url, params: { match_code: "match456" }
    end

    waiting_game.reload
    assert_equal "playing", waiting_game.status  # create_matchでplayingに更新される
    assert_equal session[:player_id], waiting_game.player2_session
    assert_redirected_to game_url(waiting_game.game)
  end

  test "create_match should redirect with alert for blank match code" do
    post network_games_create_match_url, params: { match_code: "" }
    assert_redirected_to network_games_join_url
    assert_equal "マッチングコードを入力してください", flash[:alert]
  end

  test "create_match should redirect with alert for whitespace only match code" do
    post network_games_create_match_url, params: { match_code: "   " }
    assert_redirected_to network_games_join_url
    assert_equal "マッチングコードを入力してください", flash[:alert]
  end

  test "create_match should generate session player_id if not present" do
    # セッションをクリア
    reset!

    post network_games_create_match_url, params: { match_code: "newsession" }
    assert_not_nil session[:player_id]
    assert_equal 32, session[:player_id].length # hex(16) = 32文字
  end

  test "create_match should not match with same session" do
    # 最初にセッションを確立
    post network_games_create_match_url, params: { match_code: "establish_session" }

    # 同じセッション（既に確立されたもの）で既存のゲームコードにアクセス
    assert_difference("NetworkGame.count") do
      # このテストは実際には自分自身とマッチングしようとする場面を模倣
      # 新しいゲームが作成されることを確認
      post network_games_create_match_url, params: { match_code: "establish_session" }
    end

    # 新しいゲームが作成された（マッチングしなかった）ことを確認
    games = NetworkGame.where(match_code: "establish_session")
    assert_equal 2, games.count
    assert games.all?(&:waiting?)
  end

  test "waiting should show waiting page for waiting game" do
    get network_games_waiting_url(network_game_id: @network_game.id)
    assert_response :success
    assert_select "h1", "TicTacNine"
    assert_select "h2", "対戦相手を待機中..."
  end

  test "waiting should redirect to game if already matched" do
    @network_game.update!(status: "matched", player2_session: "session2")

    get network_games_waiting_url(network_game_id: @network_game.id)

    @network_game.reload
    assert_equal "playing", @network_game.status
    assert_redirected_to game_url(@network_game.game)
  end

  test "waiting should redirect to game if already playing" do
    @network_game.update!(status: "playing", player2_session: "session2")

    get network_games_waiting_url(network_game_id: @network_game.id)
    assert_redirected_to game_url(@network_game.game)
  end

  test "check_match should return false for waiting game" do
    get check_match_network_game_url(@network_game), as: :json
    assert_response :success

    response_data = JSON.parse(response.body)
    assert_not response_data["matched"]
  end

  test "check_match should return true and game url for matched game" do
    @network_game.update!(status: "matched", player2_session: "session2")

    get check_match_network_game_url(@network_game), as: :json
    assert_response :success

    response_data = JSON.parse(response.body)
    assert response_data["matched"]
    assert_equal game_path(@network_game.game), response_data["game_url"]

    @network_game.reload
    assert_equal "playing", @network_game.status
  end

  test "check_match should return true for already playing game" do
    @network_game.update!(status: "playing", player2_session: "session2")

    get check_match_network_game_url(@network_game), as: :json
    assert_response :success

    response_data = JSON.parse(response.body)
    assert response_data["matched"]
    assert_equal game_path(@network_game.game), response_data["game_url"]
  end

  test "check_match should update matched game to playing status" do
    @network_game.update!(status: "matched", player2_session: "session2")

    get check_match_network_game_url(@network_game), as: :json

    @network_game.reload
    assert_equal "playing", @network_game.status
  end

  test "create_match flow should work end to end" do
    # プレイヤー1が新しいマッチを作成
    post network_games_create_match_url, params: { match_code: "endtoend" }
    player1_session = session[:player_id]
    network_game = NetworkGame.last

    assert_equal "waiting", network_game.status
    assert_equal player1_session, network_game.player1_session
    assert_nil network_game.player2_session
    assert_redirected_to network_games_waiting_url(network_game_id: network_game.id)

    # 新しいセッションでプレイヤー2がマッチング
    reset!
    post network_games_create_match_url, params: { match_code: "endtoend" }
    player2_session = session[:player_id]

    network_game.reload
    assert_equal "playing", network_game.status  # create_matchでplayingに更新される
    assert_equal player1_session, network_game.player1_session
    assert_equal player2_session, network_game.player2_session
    assert_redirected_to game_url(network_game.game)
  end
end
