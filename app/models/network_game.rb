class NetworkGame < ApplicationRecord
  belongs_to :game

  enum :status, {
    waiting: "waiting",
    matched: "matched",
    playing: "playing",
    finished: "finished"
  }

  validates :match_code, presence: true

  # マッチング処理
  def self.find_or_create_match(match_code, session_id)
    # 既存の待機中のゲームを探す
    waiting_game = where(match_code: match_code, status: "waiting").first

    if waiting_game && waiting_game.player1_session != session_id
      # マッチング成立
      waiting_game.update!(
        player2_session: session_id,
        status: "matched"
      )
      waiting_game
    else
      # 新しいゲームを作成
      game = Game.create!(mode: "net")
      create!(
        match_code: match_code,
        game: game,
        player1_session: session_id,
        status: "waiting"
      )
    end
  end

  # セッションIDからプレイヤー番号を取得
  def player_number(session_id)
    if player1_session == session_id
      "X"
    elsif player2_session == session_id
      "O"
    else
      nil
    end
  end

  # 対戦相手のセッションIDを取得
  def opponent_session(session_id)
    if player1_session == session_id
      player2_session
    elsif player2_session == session_id
      player1_session
    else
      nil
    end
  end
end
