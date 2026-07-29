# 文書の分類の管理。参照は全員に開き、変更は管理者へ限定する。
class DocumentCategoriesController < ApplicationController
  before_action :require_administrator
  before_action :set_document_category, only: %i[edit update]

  def index
    @document_categories = current_organization.document_categories.ordered
  end

  def new
    @document_category = current_organization.document_categories.new
  end

  def edit
  end

  def create
    @document_category = current_organization.document_categories.new(document_category_params)

    if @document_category.save
      redirect_to document_categories_path, notice: t("document_categories.created")
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @document_category.update(document_category_params)
      redirect_to document_categories_path, notice: t("document_categories.updated")
    else
      render :edit, status: :unprocessable_content
    end
  end

  private
    def set_document_category
      @document_category = current_organization.document_categories.find(params[:id])
    end

    def document_category_params
      params.expect(document_category: %i[name code position])
    end
end
