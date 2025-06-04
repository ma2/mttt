import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["currentTurn", "moveCountX", "moveCountO", "boardCountX", "boardCountO", "result", "winDialog", "winMessage", "finalBoardCountX", "finalBoardCountO", "skipDialog", "skipMessage"];
  static values = {
    gameId: Number,
    nextBoard: String,
    mode: String,
  };

  connect() {
    // 初期化
    this.moveCountX = 0;
    this.moveCountO = 0;
    this.countX = 0;
    this.countO = 0;

    // ユーザ・PC 両方の手をポップエフェクトで強調するために
    // CSS アニメーション・クラスは Tailwind に定義済み

    // Check if we need to handle skip on page load
    this.checkForSkipNeeded();
  }

  checkForSkipNeeded() {
    // Skip auto-check if we just processed a skip
    if (this.skipAutoCheck) {
      this.skipAutoCheck = false;
      return;
    }
    
    // If there's a next board restriction and that board is completed, we need to skip
    if (this.nextBoardValue) {
      const nextBoardElement = this.element.querySelector(
        `[data-board-name="${this.nextBoardValue}"]`
      );
      // Check if the board has the opacity-50 class which indicates it's completed
      if (
        nextBoardElement &&
        nextBoardElement.classList.contains("opacity-50")
      ) {
        // The next board is completed, trigger skip by sending a dummy move request
        this.triggerSkip();
      }
    }
  }

  triggerSkip() {
    // Send a move request to the completed board with any panel number
    // This will trigger the skip logic on the server
    fetch(`/games/${this.gameIdValue}/move`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector("[name=csrf-token]").content,
      },
      body: JSON.stringify({ board: this.nextBoardValue, panel: "1" }),
    })
      .then((res) => {
        if (!res.ok) throw res;
        return res.json();
      })
      .then((data) => this.onReceive(data))
      .catch((err) => {
        console.error("Skip failed:", err);
      });
  }

  // <button data-action="click->mttt#select"> により呼ばれる
  select(event) {
    const board = event.currentTarget.dataset.mtttBoardValue;
    const panel = event.currentTarget.dataset.mtttPanelValue;

    console.log(`Select clicked: board=${board}, panel=${panel}, nextBoardValue="${this.nextBoardValue}"`);

    // すでにゲーム終了している場合は何もしない
    if (this.resultTarget.textContent.length > 0) {
      console.log("Game is already over");
      return;
    }

    // 1) next_board 制限チェック
    // null や空文字列の場合は制限なし
    if (this.nextBoardValue && this.nextBoardValue !== "null" && this.nextBoardValue !== "" && board !== this.nextBoardValue) {
      console.log(`Board ${board} is not allowed, must select ${this.nextBoardValue}`);
      return;
    }

    // 2) クリック直後に一旦ボタンを disabled にする（多重クリック防止）
    event.currentTarget.disabled = true;

    // 3) /games/:id/move に POST
    fetch(`/games/${this.gameIdValue}/move`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector("[name=csrf-token]").content,
      },
      body: JSON.stringify({ board, panel }),
    })
      .then((res) => {
        if (!res.ok) throw res;
        return res.json();
      })
      .then((data) => this.onReceive(data))
      .catch(async (err) => {
        // エラーメッセージを表示
        let msg = "通信エラー";
        try {
          const js = await err.json();
          if (js.error) msg = js.error;
        } catch (_) {}
        this.showSkipDialog(msg);
        // ボタンを再度有効化
        event.currentTarget.disabled = false;
      });
  }

  // サーバから返ってきた JSON を受け取って画面を更新
  onReceive(data) {
    console.log("onReceive data:", data);
    
    // スキップの場合はメッセージを表示
    if (data.skip) {
      this.showSkipDialog(data.message);
      // 現在のプレイヤーを更新
      // nullの場合は空文字列に変換
      this.nextBoardValue = data.next_board || "";
      console.log(`Skip received, nextBoardValue set to: "${this.nextBoardValue}"`);
      
      // スキップ後はcheckForSkipNeededを実行しない
      this.skipAutoCheck = true;
    } else {
      // data.moves は配列──最初にユーザの手、PC モードなら続いて PC の手の情報が入る
      data.moves.forEach((move) => {
        this.applyMove(move);
      });

      // moves の最後を見て next_board を更新
      // nullの場合は空文字列に変換
      this.nextBoardValue = data.next_board || "";
      console.log(`Move processed, nextBoardValue set to: "${this.nextBoardValue}"`);
      
      // Check if we need to trigger skip after move
      if (data.skip_message) {
        // 通常の手の後でスキップメッセージがある場合は、nextBoardValueをクリア
        this.nextBoardValue = "";
        console.log("Skip message detected after move, clearing nextBoardValue");
      }
    }

    // スキップメッセージがある場合は表示
    if (data.skip_message) {
      this.showSkipDialog(data.skip_message);
    }

    // 全ボード div から border-4 border-sky-400 を外し、
    // next_board があれば該当ボードに border-4 border-sky-400 を再度付与
    this.element.querySelectorAll("[data-board-name]").forEach((el) => {
      el.classList.remove("border-4", "border-sky-400");
      // デフォルトのborder-2を確保
      if (!el.classList.contains("border-2")) {
        el.classList.add("border-2");
      }
    });
    if (data.next_board) {
      const nextEl = this.element.querySelector(
        `[data-board-name="${data.next_board}"]`
      );
      if (nextEl) {
        nextEl.classList.remove("border-2");
        nextEl.classList.add("border-4", "border-sky-400");
      }
    }

    // 統計情報を更新
    if (data.move_count_x !== undefined) {
      this.moveCountX = data.move_count_x;
      this.moveCountXTarget.textContent = this.moveCountX;
    }
    if (data.move_count_o !== undefined) {
      this.moveCountO = data.move_count_o;
      this.moveCountOTarget.textContent = this.moveCountO;
    }
    this.countX = data.board_count_x;
    this.boardCountXTarget.textContent = this.countX;
    this.countO = data.board_count_o;
    this.boardCountOTarget.textContent = this.countO;
    
    // 現在のプレイヤーを更新
    if (data.current_player && this.hasCurrentTurnTarget) {
      if (this.modeValue === "pc") {
        this.currentTurnTarget.textContent = data.current_player === "X" ? "あなたのターンです" : "PCのターンです";
      } else {
        this.currentTurnTarget.textContent = `${data.current_player}のターンです`;
      }
    }

    // ゲーム終了判定
    if (data.game_over) {
      let msg;
      if (data.overall_winner === "X") {
        msg = "Xの勝利！";
      } else if (data.overall_winner === "O") {
        msg = "Oの勝利！";
      } else {
        msg = "引き分けです";
      }
      
      // ダイアログに勝利メッセージを設定
      if (this.hasWinMessageTarget) {
        this.winMessageTarget.textContent = msg;
      }
      
      // 最終スコアを設定
      if (this.hasFinalBoardCountXTarget) {
        this.finalBoardCountXTarget.textContent = this.countX;
      }
      if (this.hasFinalBoardCountOTarget) {
        this.finalBoardCountOTarget.textContent = this.countO;
      }
      
      // ダイアログを表示
      if (this.hasWinDialogTarget) {
        this.winDialogTarget.showModal();
      }

      // 終了後はすべてのパネルを disabled にする
      this.element
        .querySelectorAll("button[data-mttt-board-value]")
        .forEach((b) => {
          b.disabled = true;
        });
        
      // ゲーム終了時はターン表示を空にする
      if (this.hasCurrentTurnTarget) {
        this.currentTurnTarget.textContent = "";
      }
    } else if (!data.skip) {
      // ゲームが終了していない場合、次のボードが決着済みかチェック
      this.checkForSkipNeeded();
    } else {
      // Check if we need to trigger skip for the next move
      setTimeout(() => this.checkForSkipNeeded(), 100);
    }
  }

  // 単一の move 情報 (ユーザ or PC) を UI に反映
  applyMove(move) {
    const bd = this.element.querySelector(`[data-board-name="${move.board}"]`);
    const btn = bd.querySelector(`[data-mttt-panel-value="${move.panel}"]`);
    // ボタン要素にテキストを設定 ( "X" or "O" )
    btn.textContent = move.player;

    // エフェクト：Tailwind の animate-pop を付与して一瞬飛び出す
    btn.classList.add("animate-pop");
    setTimeout(() => {
      btn.classList.remove("animate-pop");
    }, 400);

    // もしボード決着済みなら、ボード全体をグレーアウト（opacity-50）にして勝者マークを表示
    if (move.completed && move.board_winner) {
      bd.classList.add("opacity-50");
      
      // 既存の勝者マークを削除（もしあれば）
      const existingWinner = bd.querySelector('.winner-mark');
      if (existingWinner) {
        existingWinner.remove();
      }
      
      // 勝者マークを追加
      const winnerDiv = document.createElement('div');
      winnerDiv.className = 'absolute inset-0 flex items-center justify-center pointer-events-none winner-mark';
      winnerDiv.innerHTML = `<span class="text-green-500 text-8xl font-bold opacity-80">${move.board_winner}</span>`;
      bd.appendChild(winnerDiv);
    }
  }
  
  // 勝利ダイアログを閉じる
  closeDialog() {
    if (this.hasWinDialogTarget) {
      this.winDialogTarget.close();
    }
  }
  
  // スキップダイアログを表示
  showSkipDialog(message) {
    if (this.hasSkipMessageTarget && this.hasSkipDialogTarget) {
      this.skipMessageTarget.textContent = message;
      this.skipDialogTarget.showModal();
    }
  }
  
  // スキップダイアログを閉じる
  closeSkipDialog() {
    if (this.hasSkipDialogTarget) {
      this.skipDialogTarget.close();
    }
  }
}
