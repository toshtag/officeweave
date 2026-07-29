class CreateEventDepartments < ActiveRecord::Migration[8.1]
  def change
    create_table :event_departments do |t|
      t.references :event, null: false, foreign_key: true
      t.references :department, null: false, foreign_key: true

      t.timestamps
    end

    add_index :event_departments, %i[event_id department_id], unique: true,
              name: "index_event_departments_on_pair"
  end
end
