require "test_helper"

class BoardTest < ActiveSupport::TestCase
  def setup
    @game = Game.create!(mode: "local")
    @board = @game.boards.first
  end

  test "should be valid with valid attributes" do
    assert @board.valid?
  end

  test "should belong to a game" do
    assert_respond_to @board, :game
    assert_equal @game, @board.game
  end

  test "should have many panels" do
    assert_respond_to @board, :panels
    assert_equal 9, @board.panels.count
  end

  test "should create 9 panels with correct indices" do
    indices = @board.panels.pluck(:index).sort
    assert_equal (1..9).to_a, indices
  end

  test "should not be completed initially" do
    assert_not @board.completed
    assert_nil @board.winner
  end

  test "check_winner! detects horizontal win" do
    # 上段（パネル1, 2, 3）をXで埋める
    [ 1, 2, 3 ].each do |index|
      panel = @board.panels.find_by(index: index)
      panel.update!(state: "X")
    end

    @board.check_winner!

    assert @board.completed
    assert_equal "X", @board.winner
  end

  test "check_winner! detects vertical win" do
    # 左列（パネル1, 4, 7）をOで埋める
    [ 1, 4, 7 ].each do |index|
      panel = @board.panels.find_by(index: index)
      panel.update!(state: "O")
    end

    @board.check_winner!

    assert @board.completed
    assert_equal "O", @board.winner
  end

  test "check_winner! detects diagonal win" do
    # 対角線（パネル1, 5, 9）をXで埋める
    [ 1, 5, 9 ].each do |index|
      panel = @board.panels.find_by(index: index)
      panel.update!(state: "X")
    end

    @board.check_winner!

    assert @board.completed
    assert_equal "X", @board.winner
  end

  test "check_winner! detects anti-diagonal win" do
    # 逆対角線（パネル3, 5, 7）をOで埋める
    [ 3, 5, 7 ].each do |index|
      panel = @board.panels.find_by(index: index)
      panel.update!(state: "O")
    end

    @board.check_winner!

    assert @board.completed
    assert_equal "O", @board.winner
  end

  test "check_winner! detects draw when board is full" do
    # ボードを引き分けパターンで埋める（どちらも勝利しないパターン）
    # X O X
    # O O X
    # O X O
    states = [ "X", "O", "X", "O", "O", "X", "O", "X", "O" ]
    @board.panels.each_with_index do |panel, index|
      panel.update!(state: states[index])
    end

    @board.check_winner!

    assert @board.completed
    assert_nil @board.winner
  end

  test "check_winner! does not mark as completed when no winner and not full" do
    # 一部だけ埋める
    @board.panels.find_by(index: 1).update!(state: "X")
    @board.panels.find_by(index: 2).update!(state: "O")

    @board.check_winner!

    assert_not @board.completed
    assert_nil @board.winner
  end

  test "name should be present" do
    @board.name = nil
    assert_not @board.valid?
  end

  test "should validate all winning patterns" do
    winning_patterns = [
      [ 1, 2, 3 ], # 上段
      [ 4, 5, 6 ], # 中段
      [ 7, 8, 9 ], # 下段
      [ 1, 4, 7 ], # 左列
      [ 2, 5, 8 ], # 中列
      [ 3, 6, 9 ], # 右列
      [ 1, 5, 9 ], # 対角線
      [ 3, 5, 7 ]  # 逆対角線
    ]

    winning_patterns.each_with_index do |pattern, index|
      # 新しいゲームとボードを作成
      game = Game.create!(mode: "local")
      board = game.boards.first

      # パターンに従ってXを配置
      pattern.each do |panel_index|
        panel = board.panels.find_by(index: panel_index)
        panel.update!(state: "X")
      end

      board.check_winner!

      assert board.completed, "Pattern #{pattern} should be a winning pattern"
      assert_equal "X", board.winner, "Pattern #{pattern} should result in X winning"
    end
  end
end
