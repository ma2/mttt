class CreateNetworkGames < ActiveRecord::Migration[8.0]
  def change
    create_table :network_games do |t|
      t.string :match_code, null: false
      t.references :game, null: false, foreign_key: true
      t.string :player1_session
      t.string :player2_session
      t.string :status, default: "waiting"

      t.timestamps
    end

    add_index :network_games, :match_code
    add_index :network_games, :status
  end
end
