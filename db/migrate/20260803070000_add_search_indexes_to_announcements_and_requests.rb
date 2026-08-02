# お知らせと申請の検索のための索引。
#
# 文書と同じ 3 文字組の索引を置く。部分一致の検索は、索引が無いと
# 蓄積した記録を毎回走査する。R8 で取り除いた「入力の大きさに比例して
# 増える走査」を、検索の追加で戻さない。
class AddSearchIndexesToAnnouncementsAndRequests < ActiveRecord::Migration[8.1]
  def change
    add_index :announcements, :title, using: :gin, opclass: :gin_trgm_ops,
              name: "index_announcements_on_title_trigram"
    add_index :announcements, :body, using: :gin, opclass: :gin_trgm_ops,
              name: "index_announcements_on_body_trigram"
    add_index :requests, :title, using: :gin, opclass: :gin_trgm_ops,
              name: "index_requests_on_title_trigram"
    add_index :requests, :body, using: :gin, opclass: :gin_trgm_ops,
              name: "index_requests_on_body_trigram"
  end
end
