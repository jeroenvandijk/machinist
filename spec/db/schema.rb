ActiveRecord::Schema.define(:version => 0) do
  create_table :people, :force => true do |t|
    t.column :name, :string
    t.column :type, :string
    t.column :password, :string
    t.column :admin, :boolean, :default => false
  end
  
  create_table :posts, :force => true do |t|
    t.column :title, :string
    t.column :body, :text
    t.column :published, :boolean, :default => true
  end
  
  create_table :comments, :force => true do |t|
    t.column :post_id, :integer
    t.column :author_id, :integer
    t.column :body, :text
  end
  
  create_table :users, :force => true do |t|
    t.column :name, :string
    t.column :secret, :string
  end
  
  create_table :posts_users, :force => true, :id => false do |t|
    t.column :post_id, :integer
    t.column :user_id, :integer
  end
  
  create_table :subscriptions, :force => true, :id => false do |t|
    t.column :person_id, :integer
    t.column :post_id, :integer
  end
end
