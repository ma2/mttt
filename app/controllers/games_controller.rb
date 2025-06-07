class GamesController < ApplicationController
  before_action :set_game, only: [ :show, :move, :abandon, :check_abandoned, :check_opponent_move ]

  def new
    @game = Game.new
    # new.html.erb では form で mode を選択できる

    # ネットワーク対戦の未完了ゲームをクリーンアップ
    # ただし、セッションIDは保持する（次のネットワーク対戦で使用するため）
    if session[:player_id]
      cleanup_unfinished_network_games(session[:player_id])
    end

    # ブラウザキャッシュを無効化
    response.headers["Cache-Control"] = "no-cache, no-store, must-revalidate"
    response.headers["Pragma"] = "no-cache"
    response.headers["Expires"] = "0"
  end

  def howto
    # howto.html.erb で遊び方を表示
  end

  def create
    # ネットワーク対戦の場合は、network_games_join_pathにリダイレクト
    # ただし、Ajaxリクエストや意図しないフォーム送信を防ぐため、追加チェックを行う
    if params[:game][:mode] == "net"
      # リファラーが明らかに不正な場合（network_games関連のページから来た場合）のみ拒否
      if request.referer&.include?('/network_games/') && !request.referer&.include?('/network_games/join')
        Rails.logger.info "Preventing automatic redirect from network games page: #{request.referer}"
        redirect_to new_game_path
        return
      end
      
      redirect_to network_games_join_path
      return
    end

    @game = Game.create!(game_params)
    redirect_to @game
  end

  def show
    # show.html.erb に @game, @game.boards, @game.panels を渡す

    # ネットワーク対戦の場合、適切なセッションを持っているか確認
    if @game.mode == "net"
      network_game = NetworkGame.find_by(game: @game)

      # NetworkGameが存在しない、または現在のセッションが参加者でない場合
      if !network_game || ![ network_game.player1_session, network_game.player2_session ].include?(session[:player_id])
        Rails.logger.info "Unauthorized access to network game #{@game.id} by session #{session[:player_id]}"
        redirect_to new_game_path, alert: "この対戦に参加していません"
        nil
      end
    end
  end

  # POST /games/:id/move
  # ローカル／PC／ネットすべて JSON で結果を返す
  def move
    # ネットワークゲームのターン制御
    if @game.mode == "net"
      network_game = NetworkGame.find_by(game: @game)
      current_session = session[:player_id]

      # プレイヤーの権限チェック
      unless network_game&.player_number(current_session) == @game.current_player
        render json: { error: "あなたのターンではありません" }, status: :forbidden
        return
      end
    end
    # --- 1) ユーザ入力の取得 ---
    board = @game.boards.find_by!(name: params.require(:board))
    panel = board.panels.find_by!(index: params.require(:panel).to_i)

    # デバッグログ: 移動リクエストの詳細
    Rails.logger.info "===== MOVE REQUEST DEBUG ====="
    Rails.logger.info "Game #{@game.id}: Board #{board.name}, Panel #{panel.index}"
    Rails.logger.info "Current player: #{@game.current_player}"
    Rails.logger.info "Next board restriction: #{@game.next_board}"
    Rails.logger.info "Board #{board.name} completed: #{board.completed}"
    Rails.logger.info "Board #{board.name} winner: #{board.winner}"

    # デバッグログ: すべてのボードの状態
    @game.boards.each do |b|
      Rails.logger.info "Board #{b.name}: completed=#{b.completed}, winner=#{b.winner}"
    end

    # Check if attempting to play on a completed board when it's the designated next board
    if board.completed && @game.next_board == board.name
      Rails.logger.info "SKIP LOGIC TRIGGERED: Next board #{board.name} is already completed"

      # Clear next_board restriction but don't change player
      @game.update!(next_board: nil)

      Rails.logger.info "After skip: current_player=#{@game.current_player}, next_board=#{@game.next_board}"

      render json: {
        skip: true,
        message: "次の操作対象のボード#{board.name}は決着済みです。任意のボードを選択してください。",
        next_board: nil,
        current_player: @game.current_player,
        move_count: @game.moves.count,
        move_count_x: @game.moves.where(player: "X").count,
        move_count_o: @game.moves.where(player: "O").count,
        board_count_x: @game.boards.where(winner: "X").count,
        board_count_o: @game.boards.where(winner: "O").count
      }
      return
    elsif board.completed
      # Trying to play on a completed board that's not the next board - this is an error
      Rails.logger.error "ERROR: Attempting to play on completed board #{board.name} when it's not the next board"
      render json: { error: "このボードは既に決着済みです" }, status: :unprocessable_entity
      return
    end

    # --- 2) ユーザの手を反映 ---
    user_player = @game.current_player
    panel.update!(state: user_player)
    user_move = Move.create!(game: @game, board: board, panel: panel, player: user_player)

    # ボード単体の勝敗判定
    board.check_winner!
    Rails.logger.info "After check_winner: Board #{board.name} completed=#{board.completed}, winner=#{board.winner}"

    # ボードが決着した時点で全体の勝者をチェック（3つ揃った瞬間に終了）
    immediate_winner = @game.check_overall_winner if board.completed

    # 次のターゲットボードを計算
    letter_map   = ("A".."I").to_a            # index 1→"A", 2→"B", ..., 9→"I"
    target_name  = letter_map[panel.index - 1]
    next_board   = @game.boards.find_by(name: target_name)
    skip_message = nil

    Rails.logger.info "Next board calculation: panel.index=#{panel.index}, target_name=#{target_name}"
    Rails.logger.info "Next board #{target_name}: exists=#{next_board.present?}, completed=#{next_board&.completed}"

    if next_board&.completed
      next_board_name = nil
      skip_message = "次の操作対象のボード#{target_name}は決着済みです。任意のボードで続けてください。"
      Rails.logger.info "Next board is completed, setting next_board_name to nil"
      Rails.logger.info "Game mode: #{@game.mode}, Current player: #{user_player}"

      # すべてのモードで、次のボードが決着済みの場合はプレイヤーを交代させない
      Rails.logger.info "Keeping player as #{user_player} due to completed next board"
      @game.update!(
        current_player: user_player,  # プレイヤーを維持
        next_board:     nil
      )
    else
      next_board_name = next_board&.name
      Rails.logger.info "Next board is available, setting next_board_name to #{next_board_name}"

      # 通常の場合は常にプレイヤーを交代
      @game.update!(
        current_player: (user_player == "X" ? "O" : "X"),
        next_board:     next_board_name
      )
    end

    # --- 3) PC モードなら、ここで PC の手を実行 ---
    pc_move_data = nil
    if @game.mode == "pc" && @game.current_player == "O"
      pc_move_data = do_pc_move!
      # do_pc_move! は下で定義するヘルパーメソッド。
      # 返り値として { board:, panel:, player:, board_winner:, completed: } を返す
    end

    # --- 4) 最終決着判定 ---
    # ボード全体でのTic-Tac-Toeパターンを優先的にチェック
    overall_winner = immediate_winner || @game.check_overall_winner
    finished = overall_winner.present?

    # --- 5) JSON レスポンス生成 ---
    # moves 配列にユーザの手 (user_move) と PC の手 (pc_move_data) を入れてフロントに渡す
    user_move_data = {
      id:           user_move.id,
      board:        board.name,
      panel:        panel.index,
      player:       user_player,
      board_winner: board.winner,
      completed:    board.completed
    }

    result = {
      moves:          [ user_move_data ],
      next_board:     @game.next_board,
      current_player: @game.current_player,
      move_count:     @game.moves.count,
      move_count_x:   @game.moves.where(player: "X").count,
      move_count_o:   @game.moves.where(player: "O").count,
      board_count_x:  @game.boards.where(winner: "X").count,
      board_count_o:  @game.boards.where(winner: "O").count,
      game_over:      finished,
      overall_winner: overall_winner,
      skip_message:   skip_message
    }

    # PC の手があれば配列に追加
    if pc_move_data.present?
      result[:moves] << pc_move_data
      # PC の手後、ゲームを続行するなら next_board, current_player が
      # do_pc_move! の中で更新済みなので response に含まれる next_board は最新
      result[:next_board] = @game.next_board
      result[:current_player] = @game.current_player
      result[:move_count] = @game.moves.count
      result[:move_count_x] = @game.moves.where(player: "X").count
      result[:move_count_o] = @game.moves.where(player: "O").count
      result[:board_count_x] = @game.boards.where(winner: "X").count
      result[:board_count_o] = @game.boards.where(winner: "O").count

      # PCの手の後のスキップメッセージを追加
      if pc_move_data[:skip_after_pc]
        result[:skip_message] = pc_move_data[:skip_message]
      end

      # PCの手の後も勝者判定
      overall_winner = @game.check_overall_winner
      if overall_winner.present?
        result[:game_over] = true
        result[:overall_winner] = overall_winner
      end
    end

    render json: result
  end

  # ネット対戦の放棄
  def abandon
    if @game.mode != "net"
      render json: { error: "ネット対戦以外では使用できません" }, status: :bad_request
      return
    end

    network_game = NetworkGame.find_by(game: @game)
    current_session = session[:player_id]

    unless network_game&.player_number(current_session)
      render json: { error: "このゲームの参加者ではありません" }, status: :forbidden
      return
    end

    # 放棄したプレイヤーを記録（セッションクリア前に取得）
    abandon_player = network_game.player_number(current_session)

    # ゲームを終了状態に変更
    network_game.update!(status: "finished")

    # network_gamesレコードを無効化（追加の処理）
    # プレイヤーセッションをクリアして再利用不可にする
    network_game.update!(
      player1_session: nil,
      player2_session: nil,
      match_code: "#{network_game.match_code}_ABANDONED_#{Time.current.to_i}"
    )

    # 3時間以上更新されていない古いレコードも無効化
    cleanup_old_network_games
    opponent_player = abandon_player == "X" ? "O" : "X"

    render json: {
      abandoned: true,
      message: "対戦を終了しました",
      abandoner: abandon_player,
      winner: opponent_player
    }
  end

  # 対戦相手が放棄したかチェック
  def check_abandoned
    if @game.mode != "net"
      render json: { abandoned: false }
      return
    end

    network_game = NetworkGame.find_by(game: @game)

    if network_game&.finished?
      current_session = session[:player_id]
      current_player = network_game.player_number(current_session)
      opponent_player = current_player == "X" ? "O" : "X"

      render json: {
        abandoned: true,
        message: "対戦相手が対戦を終了しました",
        winner: current_player
      }
    else
      render json: { abandoned: false }
    end
  end

  # 相手の最新の手をチェック
  def check_opponent_move
    if @game.mode != "net"
      render json: { new_move: false }
      return
    end

    network_game = NetworkGame.find_by(game: @game)
    current_session = session[:player_id]

    unless network_game
      render json: { new_move: false }
      return
    end

    # 最後の手番号を取得
    last_move_id = params[:last_move_id].to_i

    # 新しい手があるかチェック
    new_moves = @game.moves.where("id > ?", last_move_id).order(:id)

    if new_moves.any?
      moves_data = new_moves.map do |move|
        {
          id: move.id,
          board: move.board.name,
          panel: move.panel.index,
          player: move.player,
          board_winner: move.board.winner,
          completed: move.board.completed
        }
      end

      render json: {
        new_move: true,
        moves: moves_data,
        next_board: @game.next_board,
        current_player: @game.current_player,
        move_count: @game.moves.count,
        move_count_x: @game.moves.where(player: "X").count,
        move_count_o: @game.moves.where(player: "O").count,
        board_count_x: @game.boards.where(winner: "X").count,
        board_count_o: @game.boards.where(winner: "O").count,
        game_over: @game.check_overall_winner.present?,
        overall_winner: @game.check_overall_winner
      }
    else
      render json: { new_move: false }
    end
  end

  private

  def set_game
    @game = Game.find(params[:id])
  end

  def game_params
    params.require(:game).permit(:mode)
  end

  # 「PC の手」をランダムに打つロジック
  # - @game.current_player が "O" のとき呼び出すことを想定
  # - 打てるパネルのうち、board:next_board か、next_board が nil or completed の場合は
  #   completed: false の board をすべて候補にしてランダムに決める
  # - ボード内の空いているパネル ("state" が nil) からランダム選択
  # - 勝敗判定、Game の current_player/next_board を更新してから、PC の手情報を返す
  def do_pc_move!
    Rails.logger.info "===== PC MOVE START ====="
    Rails.logger.info "Current next_board: #{@game.next_board}"

    # 1) PC が打つべき「ボード」を決定
    if @game.next_board.present?
      board = @game.boards.find_by(name: @game.next_board)
      Rails.logger.info "PC targeting board #{@game.next_board}: exists=#{board.present?}, completed=#{board&.completed}"

      # next_board が既に completed? なら別の board を探す
      if board&.completed
        Rails.logger.info "Target board is completed, selecting random available board"
        board = @game.boards.where(completed: false).sample
      end
    else
      Rails.logger.info "No next_board restriction, selecting random available board"
      board = @game.boards.where(completed: false).sample
    end

    Rails.logger.info "PC selected board: #{board&.name}"

    # 2) board 内の空きパネル一覧を取得し、ランダムで選択
    empty_panels = board.panels.where(state: nil)
    pc_panel = empty_panels.sample

    # 3) パネルに "O" を置き、Move レコードを作成
    player = "O"
    pc_panel.update!(state: player)
    Move.create!(game: @game, board: board, panel: pc_panel, player: player)

    # 4) ボードの勝敗判定
    board.check_winner!

    # 5) PC の手後の next_board を決定
    letter_map   = ("A".."I").to_a
    target_name  = letter_map[pc_panel.index - 1]
    next_board   = @game.boards.find_by(name: target_name)
    skip_after_pc = false

    if next_board&.completed
      next_board_name = nil
      skip_after_pc = true
      Rails.logger.info "PC move leads to completed board #{target_name}, will skip to O's turn"

      # PCの手の後、次のボードが決着済みならOのターンを維持
      @game.update!(
        current_player: "O",
        next_board:     nil
      )
    else
      next_board_name = next_board&.name
      # 通常の場合のみXに戻す
      @game.update!(
        current_player: "X",
        next_board:     next_board_name
      )
    end

    # 7) PC の手情報を返す
    {
      board:        board.name,
      panel:        pc_panel.index,
      player:       player,
      board_winner: board.winner,
      completed:    board.completed,
      skip_after_pc: skip_after_pc,
      skip_message: skip_after_pc ? "次の操作対象のボード#{target_name}は決着済みです。任意のボードで続けてください。" : nil
    }
  end

  # 3時間以上更新されていない古いネットワークゲームレコードを無効化
  def cleanup_old_network_games
    cutoff_time = 3.hours.ago
    old_games = NetworkGame.where("updated_at < ?", cutoff_time)
                          .where.not(status: "finished")

    old_games.find_each do |old_game|
      old_game.update!(
        status: "finished",
        player1_session: nil,
        player2_session: nil,
        match_code: "#{old_game.match_code}_EXPIRED_#{Time.current.to_i}"
      )
    end

    Rails.logger.info "Cleaned up #{old_games.count} expired network games"
  end

  # 指定されたセッションIDがプレイヤー1として作成した未完了ゲームのみを削除
  def cleanup_unfinished_network_games(session_id)
    unfinished_games = NetworkGame.where(
      "player1_session = ? AND status IN (?)",
      session_id, ["waiting", "matched"]
    )

    Rails.logger.info "Cleaning up #{unfinished_games.count} games created by session #{session_id}"

    unfinished_games.find_each do |network_game|
      # 関連するGameも削除
      game = network_game.game
      network_game.destroy!
      game.destroy! if game
    end
  end
end
