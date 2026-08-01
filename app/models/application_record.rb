class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  # 組織の境界は、どの模型でも同じ形で宣言できるようにする。
  include OrganizationBoundary
end
