class CreateInfoRequests < ActiveRecord::Migration
  def self.up
    create_table :form_responses do |t|
      t.column :name, :string
      t.column :content, :text
      t.column :created_at, :datetime
    end
  end

  def self.down
    drop_table :form_responses
  end
end
