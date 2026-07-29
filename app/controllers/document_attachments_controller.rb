# 添付ファイルの取得。
#
# 保存基盤が用意する経路は、URL を知っていれば誰でも取得できる。
# 文書の参照範囲を添付にも及ぼすため、独自の経路を通す。
#
# 保存先の URL へ転送せず、内容をそのまま返す。
# 転送すると、転送先の URL が有効な間は参照範囲の外からも取得できてしまう。
class DocumentAttachmentsController < ApplicationController
  before_action :set_document

  def show
    attachment = @document.attachments.find(params[:id])

    send_data attachment.download,
              filename: attachment.filename.to_s,
              type: attachment.content_type,
              disposition: "attachment"
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end

  private
    def set_document
      @document = Document.visible_to(Current.user).find(params[:document_id])
    end
end
