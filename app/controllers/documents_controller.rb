# 文書の参照と管理。
# アクセス制御は P8-T3 で扱う。現時点では組織の全員が参照できる。
class DocumentsController < ApplicationController
  before_action :set_document, only: %i[show edit update destroy]
  before_action :require_editable, only: %i[edit update destroy]

  def index
    @category_id = params[:document_category_id]
    @categories = current_organization.document_categories.ordered
    @documents = Document.visible_to(Current.user)
                         .in_category(@category_id)
                                     .recently_updated
                                     .includes(:author, :document_category, attachments_attachments: :blob)
  end

  def show
  end

  def new
    @document = current_organization.documents.new(document_category_id: params[:document_category_id])
  end

  def edit
  end

  def create
    @document = current_organization.documents.new(document_params)
    @document.author = Current.user

    if @document.save
      redirect_to @document, notice: t("documents.created")
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    remove_selected_attachments

    if @document.update(document_params)
      redirect_to @document, notice: t("documents.updated")
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @document.destroy

    redirect_to documents_path, notice: t("documents.destroyed"), status: :see_other
  end

  private
    # 取り除く添付は、追加とは別に扱う。
    # 同じ入力欄で表すと、置き換えなのか追加なのかが判別できない。
    def remove_selected_attachments
      ids = params.dig(:document, :remove_attachment_ids)
      return if ids.blank?

      @document.attachments.where(id: ids).each(&:purge)
    end

    def set_document
      @document = Document.visible_to(Current.user).find(params[:id])
    end

    def require_editable
      return if @document.editable_by?(Current.user)

      render "shared/forbidden", status: :forbidden, formats: :html
    end

    def document_params
      attributes = params.expect(
        document: [ :title, :body, :document_category_id, :visibility,
                    { attachments: [], department_ids: [] } ]
      )

      attributes[:department_ids] = [] unless attributes[:visibility] == "departments"
      attributes
    end
end
