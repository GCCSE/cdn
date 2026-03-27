class RemoveExternalAuthFieldsFromUsers < ActiveRecord::Migration[8.0]
  def change
    remove_index :users, :hca_id if index_exists?(:users, :hca_id)
    remove_column :users, :hca_id, :string if column_exists?(:users, :hca_id)
    remove_column :users, :hca_access_token, :text if column_exists?(:users, :hca_access_token)
  end
end
