class CreateAnnouncementDepartments < ActiveRecord::Migration[8.1]
  def change
    create_table :announcement_departments do |t|
      t.references :announcement, null: false, foreign_key: true
      t.references :department, null: false, foreign_key: true

      t.timestamps
    end

    add_index :announcement_departments, %i[announcement_id department_id], unique: true,
              name: "index_announcement_departments_on_pair"
  end
end
