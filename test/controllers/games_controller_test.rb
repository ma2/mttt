require "test_helper"

class GamesControllerTest < ActionDispatch::IntegrationTest
  def setup
    @game = Game.create!(mode: "local")
  end

  test "should get new" do
    get new_game_url
    assert_response :success
    assert_select "h1", "TicTacNine を始める"
  end

  test "new should cleanup unfinished network games" do
    # セッションを確立
    post network_games_create_match_url, params: { match_code: "establish_for_cleanup" }
    session_id = session[:player_id]

    # 未完了のネットワークゲームを作成
    net_game = Game.create!(mode: "net")
    network_game = NetworkGame.create!(
      game: net_game,
      match_code: "cleanup_test",
      player1_session: session_id,
      status: "waiting"
    )

    # newページにアクセス（クリーンアップを実行）
    get new_game_url

    # 未完了ゲームが削除されることを確認
    assert_nil NetworkGame.find_by(id: network_game.id)
    assert_nil Game.find_by(id: net_game.id)
  end

  test "should create game with local mode" do
    assert_difference("Game.count") do
      post games_url, params: { game: { mode: "local" } }
    end

    game = Game.last
    assert_equal "local", game.mode
    assert_redirected_to game_url(game)
  end

  test "should create game with pc mode" do
    assert_difference("Game.count") do
      post games_url, params: { game: { mode: "pc" } }
    end

    game = Game.last
    assert_equal "pc", game.mode
    assert_redirected_to game_url(game)
  end

  test "should redirect to network games join for net mode" do
    assert_no_difference("Game.count") do
      post games_url, params: { game: { mode: "net" } }
    end

    assert_redirected_to network_games_join_path
  end

  test "should show game" do
    get game_url(@game)
    assert_response :success
    assert_select "h1", "TicTacNine"
  end

  test "show should redirect for unauthorized network game access" do
    net_game = Game.create!(mode: "net")
    NetworkGame.create!(
      game: net_game,
      match_code: "test123",
      player1_session: "other_session",
      player2_session: "another_session",
      status: "playing"
    )

    get game_url(net_game)
    assert_redirected_to new_game_path
    assert_equal "この対戦に参加していません", flash[:alert]
  end

  test "should get howto" do
    get howto_url
    assert_response :success
    assert_select "h1", "TicTacNine"
    assert_select "h2", "あそびかた"
  end

  test "move should work for local game" do
    board = @game.boards.first
    panel = board.panels.first

    post move_game_url(@game),
         params: { board: board.name, panel: panel.index },
         as: :json

    assert_response :success

    response_data = JSON.parse(response.body)
    assert response_data["moves"].present?
    assert_equal @game.current_player, response_data["moves"].first["player"]
  end

  test "move should validate board and panel exist" do
    post move_game_url(@game),
         params: { board: "INVALID", panel: 1 },
         as: :json

    assert_response :not_found
  end

  test "move should prevent playing on completed board" do
    board = @game.boards.first
    board.update!(completed: true, winner: "X")
    panel = board.panels.first

    post move_game_url(@game),
         params: { board: board.name, panel: panel.index },
         as: :json

    assert_response :unprocessable_entity
  end

  test "move should work on any board when next_board is nil" do
    @game.update!(next_board: nil)
    board_a = @game.boards.find_by(name: "A")
    panel = board_a.panels.first

    post move_game_url(@game),
         params: { board: board_a.name, panel: panel.index },
         as: :json

    assert_response :success

    response_data = JSON.parse(response.body)
    assert response_data["moves"].present?
  end

  test "move should handle skip when next board is completed" do
    # 次のボードを決着させる
    next_board = @game.boards.find_by(name: "B")
    next_board.update!(completed: true, winner: "X")
    @game.update!(next_board: "B")

    # 決着済みボードに対して手を打つ
    panel = next_board.panels.first
    post move_game_url(@game),
         params: { board: next_board.name, panel: panel.index },
         as: :json

    assert_response :success

    response_data = JSON.parse(response.body)
    assert response_data["skip"]
    assert response_data["message"].include?("決着済み")
  end

  test "abandon should reject unauthenticated users" do
    net_game = Game.create!(mode: "net")
    NetworkGame.create!(
      game: net_game,
      match_code: "test123",
      player1_session: "session1",
      player2_session: "session2",
      status: "playing"
    )

    # セッションなしでabandonを試行
    post abandon_game_url(net_game), as: :json

    assert_response :forbidden

    response_data = JSON.parse(response.body)
    assert_equal "このゲームの参加者ではありません", response_data["error"]
  end

  test "abandon should reject non-network games" do
    post abandon_game_url(@game), as: :json
    assert_response :bad_request
  end

  test "check_abandoned should work for network game" do
    net_game = Game.create!(mode: "net")
    NetworkGame.create!(
      game: net_game,
      match_code: "test123",
      player1_session: "session1",
      status: "finished"
    )

    get check_abandoned_game_url(net_game), as: :json
    assert_response :success
  end

  test "check_opponent_move should work for network game" do
    net_game = Game.create!(mode: "net")

    get check_opponent_move_game_url(net_game, last_move_id: 0), as: :json
    assert_response :success

    response_data = JSON.parse(response.body)
    assert_not response_data["new_move"]
  end

  test "pc mode should make pc move after user move" do
    pc_game = Game.create!(mode: "pc")
    board = pc_game.boards.first
    panel = board.panels.first

    post move_game_url(pc_game),
         params: { board: board.name, panel: panel.index },
         as: :json

    assert_response :success

    response_data = JSON.parse(response.body)
    # ユーザーの手とPCの手、両方があることを確認
    assert_equal 2, response_data["moves"].length
    assert_equal "X", response_data["moves"].first["player"]  # ユーザー
    assert_equal "O", response_data["moves"].second["player"] # PC
  end

  test "should detect game over condition" do
    # ボードA, B, Cを"X"で勝利させる
    [ "A", "B", "C" ].each do |board_name|
      board = @game.boards.find_by(name: board_name)
      board.update!(winner: "X", completed: true)
    end

    # 任意の手を打つ
    remaining_board = @game.boards.find_by(completed: false)
    panel = remaining_board.panels.first

    post move_game_url(@game),
         params: { board: remaining_board.name, panel: panel.index },
         as: :json

    assert_response :success

    response_data = JSON.parse(response.body)
    assert response_data["game_over"]
    assert_equal "X", response_data["overall_winner"]
  end
end
