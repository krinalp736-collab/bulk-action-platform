class CreateContacts < ActiveRecord::Migration[8.1]
  def change
    create_table :contacts do |t|
      t.string :account_id, null: false
      t.string :name, null: false
      t.string :email, null: false
      t.integer :age
      t.string :status, null: false, default: "lead"

      t.timestamps
    end

    add_index :contacts, :account_id
    add_index :contacts, [ :account_id, :status ]
    add_index :contacts, [ :account_id, :email ]
    add_index :contacts, :email
  end
end
