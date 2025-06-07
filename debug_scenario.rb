#!/usr/bin/env ruby
# デバッグ用スクリプト：Player AとPlayer Bのマッチングプロセスをシミュレート

require_relative 'config/environment'

Rails.logger = Logger.new(STDOUT)
Rails.logger.level = Logger::INFO

puts "=== デバッグシナリオ開始 ==="

# 既存のNetworkGameとGameをクリア
NetworkGame.destroy_all
Game.where(mode: 'net').destroy_all

puts "Step 1: Player Aがマッチングコードを入力してゲーム作成"
match_code = "DEBUG123"
player_a_session = "player_a_session_#{SecureRandom.hex(8)}"

# Player Aがゲーム作成
network_game_a = NetworkGame.find_or_create_match(match_code, player_a_session)
puts "Player A created NetworkGame #{network_game_a.id}"
puts "Status: #{network_game_a.status}, Player1: #{network_game_a.player1_session}"

puts "\nStep 2: Player Bが同じマッチングコードを入力"
player_b_session = "player_b_session_#{SecureRandom.hex(8)}"

# Player Bがマッチング
network_game_b = NetworkGame.find_or_create_match(match_code, player_b_session)
puts "Player B matched with NetworkGame #{network_game_b.id}"
puts "Status: #{network_game_b.status}, Player1: #{network_game_b.player1_session}, Player2: #{network_game_b.player2_session}"

puts "\nStep 3: Player Aのポーリング検証"
# Player Aのセッションで check_match をシミュレート
puts "Player A session: #{player_a_session}"
puts "Player A is participant: #{[network_game_b.player1_session, network_game_b.player2_session].include?(player_a_session)}"

puts "\nStep 4: Player Bのセッション検証"
puts "Player B session: #{player_b_session}"
puts "Player B is participant: #{[network_game_b.player1_session, network_game_b.player2_session].include?(player_b_session)}"

puts "\n=== 現在のNetworkGame状態 ==="
network_game_b.reload
puts "ID: #{network_game_b.id}"
puts "Match Code: #{network_game_b.match_code}"
puts "Status: #{network_game_b.status}"
puts "Player1 Session: #{network_game_b.player1_session}"
puts "Player2 Session: #{network_game_b.player2_session}"
puts "Game ID: #{network_game_b.game_id}"

puts "\n=== デバッグシナリオ完了 ==="