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
    
    Rails.logger.info "=== NetworkGame.find_or_create_match ==="
    Rails.logger.info "Match code: #{match_code}, Session ID: #{session_id}"
    Rails.logger.info "Waiting game found: #{waiting_game&.id}, player1: #{waiting_game&.player1_session}"

    if waiting_game && waiting_game.player1_session != session_id
      # マッチング成立
      Rails.logger.info "Match found! Updating game #{waiting_game.id}"
      waiting_game.update!(
        player2_session: session_id,
        status: "matched"
      )
      waiting_game
    else
      # 新しいゲームを作成
      Rails.logger.info "Creating new game"
      game = Game.create!(mode: "net")
      new_network_game = create!(
        match_code: match_code,
        game: game,
        player1_session: session_id,
        status: "waiting"
      )
      Rails.logger.info "Created NetworkGame #{new_network_game.id} for Game #{game.id}"
      new_network_game
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
