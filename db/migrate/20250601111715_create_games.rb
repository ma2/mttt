class CreateGames < ActiveRecord::Migration[8.0]
  def change
    create_table :games do |t|
      t.string :mode,           null: false, default: "local"
      t.string :current_player, null: false, default: "X"
      t.string :next_board
      t.timestamps
    end
  end
end
