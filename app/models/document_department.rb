# 文書と、その参照を許す部門の結びつき。
class DocumentDepartment < ApplicationRecord
  belongs_to :document
  belongs_to :department

  validates :department_id, uniqueness: { scope: :document_id }
end
