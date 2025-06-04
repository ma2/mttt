class NetworkGamesController < ApplicationController
  def join
    # マッチングコード入力画面
  end

  def create_match
    match_code = params[:match_code].to_s.strip

    if match_code.blank?
      redirect_to network_games_join_path, alert: "マッチングコードを入力してください"
      return
    end

    # セッションIDがない場合は生成
    session[:player_id] ||= SecureRandom.hex(16)

    network_game = NetworkGame.find_or_create_match(match_code, session[:player_id])

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
    @network_game = NetworkGame.find(params[:network_game_id])

    # 既にマッチングしている場合はゲーム画面へ
    if @network_game.matched? || @network_game.playing?
      @network_game.update!(status: "playing") if @network_game.matched?
      redirect_to game_path(@network_game.game)
    end
  end

  def check_match
    network_game = NetworkGame.find(params[:id])

    if network_game.matched?
      network_game.update!(status: "playing")
      render json: { matched: true, game_url: game_path(network_game.game) }
    else
      render json: { matched: false }
    end
  end
end
