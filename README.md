# TicTacNine

9つのボードで戦う究極の戦略ゲーム

<div align="center">
  <img src="/public/logo.svg" alt="TicTacNine Logo" width="120" height="120">
</div>

## 概要

TicTacNineは、通常の三目並べを9つ組み合わせた戦略的なゲームです。各ボードで勝利を収めながら、全体のボード配置でも勝利パターンを作ることを目指します。あなたの手によって相手の次の手が制限される、奥深い戦略が求められるゲームです。

## ゲームルール

### 基本ルール
1. ゲームは9つのボード（A-I）で構成され、各ボードには9つのパネル（1-9）があります
2. プレイヤーが選んだパネルの位置によって、相手が次に操作するボードが決まります
   - 例：パネル5に置く → 相手は次にボードE（中央）で操作
3. 指定されたボードが既に決着している場合は、任意のボードを選択できます
4. 各ボードで縦・横・斜めのいずれかに3つ揃えるとそのボードを獲得

### 勝利条件
1. **最優先**: 9つのボードのうち3つを縦・横・斜めのいずれかに並べて勝利
2. **補助条件**: すべてのボードが決着した場合、より多くのボードを獲得したプレイヤーの勝利

### 戦略のポイント
- 相手の次の手を制限する位置を選ぶ
- 複数のボードで同時に勝利パターンを狙う  
- 決着済みボードを活用して自由に手を選ぶ

## ゲームモード

### 🏠 ローカルモード
同じ画面で2人のプレイヤーが交互にプレイ。友達や家族との対戦に最適です。

### 🤖 PCモード  
コンピュータ（ランダム戦略）との対戦。ルールを覚えたい初心者におすすめです。

### 🌐 ネットワークモード
オンラインで世界中のプレイヤーと対戦。マッチングコードを共有して対戦相手を見つけましょう。

## 主な機能

- **リアルタイム対戦**: ネットワークモードでの即座な手の同期
- **スキップ機能**: 決着済みボードへの移動時の自動スキップ
- **視覚的フィードバック**: 勝利ボードのハイライト、大きな勝者マーク
- **対戦統計**: X・Oそれぞれの手数とボード獲得数の表示
- **対戦終了機能**: ネットワーク対戦の途中離脱に対応
- **レスポンシブデザイン**: スマートフォンやタブレットでも快適にプレイ

## 技術スタック

- **Backend**: Ruby on Rails 8.0.2, Ruby 3.3.6
- **Frontend**: Hotwire (Turbo + Stimulus), Tailwind CSS v4
- **Database**: SQLite3（開発環境）
- **Real-time**: ポーリングベースの手動同期
- **Testing**: Minitest
- **Deployment**: Docker + Kamal

## セットアップ

```bash
# リポジトリのクローン
git clone [repository-url]
cd mttt

# 依存関係のインストール
bundle install

# データベースのセットアップ
bin/rails db:create
bin/rails db:migrate

# 開発サーバーの起動（Rails + Tailwind CSS）
bin/dev
```

ブラウザで http://localhost:3000 にアクセスしてTicTacNineを開始できます。

### 初回プレイの手順
1. トップページで対戦モードを選択
2. 「あそびかた」でルールを確認（推奨）
3. ゲーム開始！

## 開発

### テストの実行
```bash
# すべてのテストを実行
bin/rails test

# システムテストのみ実行
bin/rails test:system
```

### アーキテクチャ

```
app/
├── controllers/
│   ├── games_controller.rb          # ゲーム管理、手の処理
│   └── network_games_controller.rb  # ネット対戦のマッチング
├── models/
│   ├── game.rb                      # ゲーム状態、勝利判定
│   ├── board.rb                     # 個別ボードの管理
│   ├── panel.rb                     # パネル状態
│   ├── move.rb                      # 手の履歴
│   └── network_game.rb              # ネット対戦の管理
├── javascript/controllers/
│   └── mttt_controller.js           # フロントエンド制御
└── views/
    ├── games/                       # ゲーム画面
    └── network_games/               # ネット対戦画面
```

## 今後の展開

- [ ] AIによる賢いPC対戦相手
- [ ] 対戦記録・統計機能
- [ ] トーナメント機能
- [ ] チーム戦モード
- [ ] カスタムルール設定

## コントリビューション

1. フォークしてブランチを作成
2. 機能追加・バグ修正を実施
3. テストを追加・実行
4. プルリクエストを作成

## ライセンス

このプロジェクトはMITライセンスの下で公開されています。

---

**TicTacNine** - 戦略と運の絶妙なバランスを楽しめる、新感覚の○×ゲーム