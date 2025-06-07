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

  test "join should cleanup unfinished games" do
    # セッションを設定して未完了ゲームを作成
    post network_games_create_match_url, params: { match_code: "cleanup_test" }
    session_id = session[:player_id]
    unfinished_game = NetworkGame.last

    assert_equal "waiting", unfinished_game.status
    assert_equal session_id, unfinished_game.player1_session

    # joinページにアクセス（クリーンアップが実行される）
    get network_games_join_url

    # 未完了ゲームが削除されることを確認（セッションは保持）
    assert_nil NetworkGame.find_by(id: unfinished_game.id)
    assert_equal session_id, session[:player_id]
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

  test "create_match should always generate new session player_id" do
    # 最初のリクエスト
    post network_games_create_match_url, params: { match_code: "session_test1" }
    first_session_id = session[:player_id]
    assert_not_nil first_session_id
    assert_equal 32, first_session_id.length # hex(16) = 32文字

    # 2回目のリクエスト（新しいセッションIDが生成されるはず）
    post network_games_create_match_url, params: { match_code: "session_test2" }
    second_session_id = session[:player_id]
    assert_not_nil second_session_id
    assert_not_equal first_session_id, second_session_id
  end


  test "waiting should show waiting page for waiting game" do
    # セッションを設定
    post network_games_create_match_url, params: { match_code: "waiting_test" }
    network_game = NetworkGame.last

    get network_games_waiting_url(network_game_id: network_game.id)
    assert_response :success
    assert_select "h1", "TicTacNine"
    assert_select "h2", "対戦相手を待機中..."
  end

  test "waiting should redirect to join if not participant" do
    # ゲームを作成
    game = Game.create!(mode: "net")
    network_game = NetworkGame.create!(
      match_code: "test123",
      game: game,
      player1_session: "other_session",
      status: "waiting"
    )

    # 別のセッションでアクセス
    get network_games_waiting_url(network_game_id: network_game.id)
    assert_redirected_to network_games_join_path
    assert_equal "この対戦に参加していません", flash[:alert]
  end

  test "waiting should redirect to join if game not found" do
    get network_games_waiting_url(network_game_id: 99999)
    assert_redirected_to network_games_join_path
    assert_equal "対戦が見つかりません", flash[:alert]
  end

  test "waiting should redirect to game if already matched" do
    # セッションを設定して参加者としてアクセス
    post network_games_create_match_url, params: { match_code: "matched_test" }
    network_game = NetworkGame.last

    # 別のプレイヤーを追加してマッチング状態にする
    network_game.update!(status: "matched", player2_session: "session2")

    get network_games_waiting_url(network_game_id: network_game.id)

    network_game.reload
    assert_equal "playing", network_game.status
    assert_redirected_to game_url(network_game.game)
  end

  test "waiting should redirect to game if already playing" do
    # セッションを設定して参加者としてアクセス
    post network_games_create_match_url, params: { match_code: "playing_test" }
    network_game = NetworkGame.last

    network_game.update!(status: "playing", player2_session: "session2")

    get network_games_waiting_url(network_game_id: network_game.id)
    assert_redirected_to game_url(network_game.game)
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
