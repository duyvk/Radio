class AddPictureToUser < ActiveRecord::Migration
  def self.up
    add_column :users, :picture_file_name, :string
    add_column :users, :picture_content_type, :string
    add_column :users, :picture_file_size, :integer
  end

  def self.down
    remove_column :users, :picture_file_size
    remove_column :users, :picture_content_type
    remove_column :users, :picture_file_name
  end
end
