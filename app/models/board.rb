class Board < ApplicationRecord
  belongs_to :game
  has_many   :panels, dependent: :destroy

  # ボード内 3x3 の決着判定メソッド
  def check_winner!
    return if completed

    # 勝利パターンのインデックス
    lines = [
      [ 1, 2, 3 ], [ 4, 5, 6 ], [ 7, 8, 9 ],
      [ 1, 4, 7 ], [ 2, 5, 8 ], [ 3, 6, 9 ],
      [ 1, 5, 9 ], [ 3, 5, 7 ]
    ]

    lines.each do |a, b, c|
      sa = panels.find_by(index: a).state
      sb = panels.find_by(index: b).state
      sc = panels.find_by(index: c).state
      next if sa.blank? || sb.blank? || sc.blank?
      if sa == sb && sb == sc
        Rails.logger.info "Board #{name}: Winner found! #{sa} wins with line #{[ a, b, c ]}"
        update!(winner: sa, completed: true)
        return sa
      end
    end

    # 引き分けチェック: すべてのパネルが埋まっているか
    if panels.where(state: nil).count == 0
      Rails.logger.info "Board #{name}: Draw detected - all panels filled"
      update!(winner: "D", completed: true)
      return "D"
    end

    nil
  end
end
