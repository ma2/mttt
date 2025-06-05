class Game < ApplicationRecord
  has_many :boards,  dependent: :destroy
  has_many :panels,  through: :boards
  has_many :moves,   dependent: :destroy

  # (Optional) ネットワーク対戦用に UUID を付与したい場合など、コールバックを追加しても OK

  after_create :setup_boards_and_panels

  enum :mode, {
    local: "local",
    pc:    "pc",
    net:   "net"
  }

  # ゲーム全体の勝者を判定
  def check_overall_winner
    # ボードをA-Iの順番で3x3配列として扱う
    # A B C
    # D E F
    # G H I

    # 勝利パターン
    lines = [
      [ "A", "B", "C" ], [ "D", "E", "F" ], [ "G", "H", "I" ], # 横
      [ "A", "D", "G" ], [ "B", "E", "H" ], [ "C", "F", "I" ], # 縦
      [ "A", "E", "I" ], [ "C", "E", "G" ]                    # 斜め
    ]

    # 各ラインをチェック
    lines.each do |line|
      board_winners = boards.where(name: line).pluck(:winner)
      next if board_winners.include?(nil) || board_winners.include?("")

      # 3つとも同じ勝者なら、そのプレイヤーが勝利
      if board_winners.uniq.size == 1
        return board_winners.first
      end
    end

    # Tic-Tac-Toeパターンが成立しない場合
    # すべてのボードが決着済みなら、勝利ボード数で判定
    if boards.where(completed: false).empty?
      x_count = boards.where(winner: "X").count
      o_count = boards.where(winner: "O").count

      if x_count > o_count
        return "X"
      elsif o_count > x_count
        return "O"
      else
        return "D" # 引き分け
      end
    end

    # まだゲーム続行中
    nil
  end

  private

  # 初回作成時に 9 つのボードとそれぞれ 9 つのパネルを作成
  def setup_boards_and_panels
    ("A".."I").each do |name|
      b = boards.create!(name: name)
      (1..9).each { |i| b.panels.create!(index: i) }
    end
    # 最初のターゲットボードは nil、どこでも打てる
    update!(next_board: nil)
  end
end
