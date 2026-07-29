# 文書の参照と管理。
# アクセス制御は P8-T3 で扱う。現時点では組織の全員が参照できる。
class DocumentsController < ApplicationController
  before_action :set_document, only: %i[show edit update destroy]
  before_action :require_editable, only: %i[edit update destroy]

  def index
    @category_id = params[:document_category_id]
    @categories = current_organization.document_categories.ordered
    @documents = current_organization.documents
                                     .in_category(@category_id)
                                     .recently_updated
                                     .includes(:author, :document_category)
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
    def set_document
      @document = current_organization.documents.find(params[:id])
    end

    def require_editable
      return if @document.editable_by?(Current.user)

      render "shared/forbidden", status: :forbidden, formats: :html
    end

    def document_params
      params.expect(document: %i[title body document_category_id])
    end
end
