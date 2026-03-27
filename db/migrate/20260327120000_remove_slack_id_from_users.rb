class RemoveSlackIdFromUsers < ActiveRecord::Migration[8.0]
  def change
    remove_index :users, :slack_id if index_exists?(:users, :slack_id)
    remove_column :users, :slack_id, :string if column_exists?(:users, :slack_id)
  end
end
