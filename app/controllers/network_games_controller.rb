class NetworkGamesController < ApplicationController
  def join
    # マッチングコード入力画面
    # 新しいマッチング試行のためにセッションをクリア
    if session[:player_id]
      # 現在のセッションに関連する未完了のNetworkGameをクリーンアップ
      cleanup_unfinished_games(session[:player_id])
      # セッションIDは新たに生成されるまで保持（create_matchで新規生成される）
    end

    # ブラウザキャッシュを無効化
    response.headers["Cache-Control"] = "no-cache, no-store, must-revalidate"
    response.headers["Pragma"] = "no-cache"
    response.headers["Expires"] = "0"
  end

  def create_match
    match_code = params[:match_code].to_s.strip

    if match_code.blank?
      redirect_to network_games_join_path, alert: "マッチングコードを入力してください"
      return
    end

    # 既存のセッションがある場合は、そのセッションの未完了ゲームをクリーンアップ
    if session[:player_id]
      cleanup_unfinished_games(session[:player_id])
    end

    # セッションIDがない場合は生成（既存がある場合は新規生成）
    session[:player_id] = SecureRandom.hex(16)

    Rails.logger.info "=== CREATE_MATCH ==="
    Rails.logger.info "New session_id: #{session[:player_id]}"
    Rails.logger.info "Match code: #{match_code}"

    network_game = NetworkGame.find_or_create_match(match_code, session[:player_id])

    Rails.logger.info "NetworkGame found/created: #{network_game.id}, status: #{network_game.status}"
    Rails.logger.info "Game ID: #{network_game.game_id}"

    if network_game.matched?
      # マッチング成立、ゲーム開始
      network_game.update!(status: "playing")
      redirect_to game_path(network_game.game)
    else
      # 待機中
      redirect_to network_games_waiting_path(network_game_id: network_game.id)
    end
  end

  def waiting
    @network_game = NetworkGame.find_by(id: params[:network_game_id])

    # NetworkGameが見つからない場合はjoinページへ
    unless @network_game
      redirect_to network_games_join_path, alert: "対戦が見つかりません"
      return
    end

    # 現在のセッションがこのゲームの参加者でない場合はjoinページへ
    current_session = session[:player_id]
    unless current_session && [ @network_game.player1_session, @network_game.player2_session ].include?(current_session)
      redirect_to network_games_join_path, alert: "この対戦に参加していません"
      return
    end

    # 既にマッチングしている場合はゲーム画面へ
    if @network_game.matched? || @network_game.playing?
      @network_game.update!(status: "playing") if @network_game.matched?
      redirect_to game_path(@network_game.game)
    end
  end

  def check_match
    network_game = NetworkGame.find(params[:id])

    if network_game.matched? || network_game.playing?
      # マッチング済みまたはプレイ中の場合
      network_game.update!(status: "playing") if network_game.matched?
      render json: { matched: true, game_url: game_path(network_game.game) }
    else
      render json: { matched: false }
    end
  end

  private

  def cleanup_unfinished_games(session_id)
    # 指定されたセッションIDに関連するすべてのNetworkGameを削除（playingも含む）
    # キャンセル後は完全にクリーンスタートするため
    unfinished_games = NetworkGame.where(
      "(player1_session = ? OR player2_session = ?)",
      session_id, session_id
    )

    Rails.logger.info "=== CLEANUP START ==="
    Rails.logger.info "Cleaning up #{unfinished_games.count} games for session #{session_id}"

    unfinished_games.find_each do |network_game|
      Rails.logger.info "Deleting NetworkGame #{network_game.id} (match_code: #{network_game.match_code}, status: #{network_game.status})"
      # 関連するGameも削除
      game = network_game.game
      game_id = game&.id
      network_game.destroy!
      if game
        game.destroy!
        Rails.logger.info "Deleted Game #{game_id}"
      end
    end
    Rails.logger.info "=== CLEANUP END ==="
  end
end
