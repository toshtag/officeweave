# お知らせと申請の検索のための索引。
#
# 文書と同じ 3 文字組の索引を置く。部分一致の検索は、索引が無いと
# 蓄積した記録を毎回走査する。読み込む量を記録の数に比例させないという
# 決めを、検索を足したことで崩さない。
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
