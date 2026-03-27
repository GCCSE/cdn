class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.string :email
      t.string :name
      t.boolean :is_admin, default: false, null: false

      t.timestamps
    end
  end
end
