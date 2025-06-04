class CreatePanels < ActiveRecord::Migration[8.0]
  def change
    create_table :panels do |t|
      t.references :board, null: false, foreign_key: true
      t.integer :index,    null: false # 1～9
      t.string  :state                 # nil / “X” / “O”
      t.timestamps
    end
  end
end
