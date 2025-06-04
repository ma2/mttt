class CreateMoves < ActiveRecord::Migration[8.0]
  def change
    create_table :moves do |t|
      t.references :game,  null: false, foreign_key: true
      t.references :board, null: false, foreign_key: true
      t.references :panel, null: false, foreign_key: true
      t.string     :player, null: false
      t.timestamps
    end
  end
end
