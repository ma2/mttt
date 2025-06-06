require "test_helper"

class NetworkGameTest < ActiveSupport::TestCase
  def setup
    @game = Game.create!(mode: "net")
    @network_game = NetworkGame.create!(
      match_code: "test123",
      game: @game,
      player1_session: "session1",
      status: "waiting"
    )
  end

  test "should be valid with valid attributes" do
    assert @network_game.valid?
  end

  test "should belong to a game" do
    assert_respond_to @network_game, :game
    assert_equal @game, @network_game.game
  end

  test "should require match_code" do
    @network_game.match_code = nil
    assert_not @network_game.valid?
  end

  test "should have valid status enum values" do
    assert NetworkGame.new(match_code: "test", game: @game, status: "waiting").valid?
    assert NetworkGame.new(match_code: "test", game: @game, status: "matched").valid?
    assert NetworkGame.new(match_code: "test", game: @game, status: "playing").valid?
    assert NetworkGame.new(match_code: "test", game: @game, status: "finished").valid?
  end

  test "find_or_create_match creates new game when no waiting game exists" do
    network_game = NetworkGame.find_or_create_match("newcode", "newsession")

    assert network_game.persisted?
    assert_equal "newcode", network_game.match_code
    assert_equal "newsession", network_game.player1_session
    assert_nil network_game.player2_session
    assert_equal "waiting", network_game.status
  end

  test "find_or_create_match matches with existing waiting game" do
    waiting_game = NetworkGame.create!(
      match_code: "match123",
      game: Game.create!(mode: "net"),
      player1_session: "player1",
      status: "waiting"
    )

    matched_game = NetworkGame.find_or_create_match("match123", "player2")

    assert_equal waiting_game.id, matched_game.id
    assert_equal "player1", matched_game.player1_session
    assert_equal "player2", matched_game.player2_session
    assert_equal "matched", matched_game.status
  end

  test "find_or_create_match does not match with same session" do
    waiting_game = NetworkGame.create!(
      match_code: "same123",
      game: Game.create!(mode: "net"),
      player1_session: "samesession",
      status: "waiting"
    )

    # 同じセッションでマッチングを試行
    result = NetworkGame.find_or_create_match("same123", "samesession")

    # 新しいゲームが作成されるべき
    assert_not_equal waiting_game.id, result.id
    assert_equal "samesession", result.player1_session
    assert_nil result.player2_session
    assert_equal "waiting", result.status
  end

  test "player_number returns correct player for session" do
    @network_game.update!(player2_session: "session2")

    assert_equal "X", @network_game.player_number("session1")
    assert_equal "O", @network_game.player_number("session2")
    assert_nil @network_game.player_number("unknown")
  end

  test "opponent_session returns correct opponent session" do
    @network_game.update!(player2_session: "session2")

    assert_equal "session2", @network_game.opponent_session("session1")
    assert_equal "session1", @network_game.opponent_session("session2")
    assert_nil @network_game.opponent_session("unknown")
  end

  test "should transition through status states correctly" do
    # waiting -> matched
    @network_game.update!(status: "matched", player2_session: "session2")
    assert @network_game.matched?

    # matched -> playing
    @network_game.update!(status: "playing")
    assert @network_game.playing?

    # playing -> finished
    @network_game.update!(status: "finished")
    assert @network_game.finished?
  end

  test "find_or_create_match handles multiple sessions correctly" do
    match_code = "multi123"

    # 最初のプレイヤー
    game1 = NetworkGame.find_or_create_match(match_code, "player1")
    assert_equal "waiting", game1.status
    assert_equal "player1", game1.player1_session

    # 2番目のプレイヤー（マッチング成立）
    game2 = NetworkGame.find_or_create_match(match_code, "player2")
    assert_equal game1.id, game2.id
    assert_equal "matched", game2.status
    assert_equal "player2", game2.player2_session

    # 3番目のプレイヤー（新しいゲーム作成）
    game3 = NetworkGame.find_or_create_match(match_code, "player3")
    assert_not_equal game1.id, game3.id
    assert_equal "waiting", game3.status
    assert_equal "player3", game3.player1_session
  end
end
