class Move < ApplicationRecord
  belongs_to :game
  belongs_to :board
  belongs_to :panel

  # Net モードで ActionCable を使う場合に使う想定。今回はローカル/PC では不要だが一応定義だけ。
  after_create :broadcast_move

  private

  def broadcast_move
    # GameChannel.broadcast_to(game, payload) など
    # 今回のローカル／PCモードでは使わないため空でもよい
  end
end
