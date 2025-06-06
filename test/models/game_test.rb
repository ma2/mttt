require "test_helper"

class GameTest < ActiveSupport::TestCase
  def setup
    @game = Game.create!(mode: "local")
  end

  test "should be valid with valid attributes" do
    assert @game.valid?
  end

  test "should have default current_player as X" do
    assert_equal "X", @game.current_player
  end

  test "should have valid mode enum values" do
    assert Game.new(mode: "local").valid?
    assert Game.new(mode: "pc").valid?
    assert Game.new(mode: "net").valid?
  end

  test "should create 9 boards after creation" do
    assert_equal 9, @game.boards.count
    assert_equal %w[A B C D E F G H I], @game.boards.pluck(:name).sort
  end

  test "each board should have 9 panels" do
    @game.boards.each do |board|
      assert_equal 9, board.panels.count
      assert_equal (1..9).to_a, board.panels.pluck(:index).sort
    end
  end

  test "check_overall_winner returns nil when no winner" do
    assert_nil @game.check_overall_winner
  end

  test "check_overall_winner detects horizontal win" do
    # ボードA, B, Cを"X"で勝利させる
    [ @game.boards.find_by(name: "A"), @game.boards.find_by(name: "B"), @game.boards.find_by(name: "C") ].each do |board|
      board.update!(winner: "X", completed: true)
    end

    assert_equal "X", @game.check_overall_winner
  end

  test "check_overall_winner detects vertical win" do
    # ボードA, D, Gを"O"で勝利させる
    [ @game.boards.find_by(name: "A"), @game.boards.find_by(name: "D"), @game.boards.find_by(name: "G") ].each do |board|
      board.update!(winner: "O", completed: true)
    end

    assert_equal "O", @game.check_overall_winner
  end

  test "check_overall_winner detects diagonal win" do
    # ボードA, E, Iを"X"で勝利させる
    [ @game.boards.find_by(name: "A"), @game.boards.find_by(name: "E"), @game.boards.find_by(name: "I") ].each do |board|
      board.update!(winner: "X", completed: true)
    end

    assert_equal "X", @game.check_overall_winner
  end

  test "check_overall_winner returns majority winner when all boards completed" do
    # 5つのボードを"X"で勝利、4つを"O"で勝利させる
    x_boards = @game.boards.limit(5)
    o_boards = @game.boards.offset(5).limit(4)

    x_boards.each { |board| board.update!(winner: "X", completed: true) }
    o_boards.each { |board| board.update!(winner: "O", completed: true) }

    assert_equal "X", @game.check_overall_winner
  end

  test "check_overall_winner returns draw when tied on completed boards" do
    # すべてのボードを決着させるが、同数勝利にする
    # ライン勝利にならないように配置
    # A B C
    # D E F
    # G H I
    # X: A, E, F, H (どのラインも成立しない配置)
    # O: B, C, D, G
    # Draw: I
    x_board_names = [ "A", "E", "F", "H" ]
    o_board_names = [ "B", "C", "D", "G" ]
    draw_board_name = "I"

    x_board_names.each do |name|
      board = @game.boards.find_by(name: name)
      board.update!(winner: "X", completed: true)
    end

    o_board_names.each do |name|
      board = @game.boards.find_by(name: name)
      board.update!(winner: "O", completed: true)
    end

    draw_board = @game.boards.find_by(name: draw_board_name)
    draw_board.update!(winner: nil, completed: true)

    assert_equal "D", @game.check_overall_winner
  end

  test "associations are properly set up" do
    assert_respond_to @game, :boards
    assert_respond_to @game, :moves
    assert_equal 9, @game.boards.count
    assert_equal 0, @game.moves.count
  end

  test "game creates boards in correct order" do
    board_names = @game.boards.order(:id).pluck(:name)
    assert_equal %w[A B C D E F G H I], board_names
  end
end
