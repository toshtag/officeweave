class AddSearchIndexesToDocuments < ActiveRecord::Migration[8.1]
  def change
    # 3 文字組による索引。
    # 語の区切りを空白で判断する仕組みは、日本語の文章では語を切り出せない。
    # 3 文字組であれば、区切りのない文章でも部分一致を索引で引ける。
    enable_extension "pg_trgm"

    add_index :documents, :title, using: :gin, opclass: :gin_trgm_ops,
              name: "index_documents_on_title_trigram"
    add_index :documents, :body, using: :gin, opclass: :gin_trgm_ops,
              name: "index_documents_on_body_trigram"
  end
end
