class AddShortNameToRoutes < ActiveRecord::Migration
  def self.up
    add_column :routes, :short_name, :string
  end

  def self.down
    remove_column :routes, :short_name
  end
end
