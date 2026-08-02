# 文書の参照と管理。
# アクセス制御は P8-T3 で扱う。現時点では組織の全員が参照できる。
class DocumentsController < ApplicationController
  before_action :set_document, only: %i[show edit update destroy]
  before_action :require_editable, only: %i[edit update destroy]

  def index
    @query = params[:query]
    @category_id = params[:document_category_id]
    @categories = current_organization.document_categories.ordered
    # 添付は一覧に出さない。先読みすると、添付を持たない文書まで含めて
    # 一覧の要求ごとに関連と実体を読むことになる。
    @documents = Document.visible_to(Current.user)
                         .search(@query)
                         .in_category(@category_id)
                         .recently_updated
                         .listed
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
    if update_document_and_attachments
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
    # 属性の変更、添付の追加、選択した添付の取り外しをひとつの更新として扱う。
    # 途中で失敗した場合は何も反映しない。取り外しを先に確定させると、
    # 検証に失敗した更新でも添付だけが消えてしまう。
    #
    # 新しいファイルは既存の添付への追加として扱う。代入で渡すと置き換えになり、
    # 追加のつもりの操作で既存の添付が失われる。
    # 取り除く添付は remove_attachment_ids だけで表し、必ず自文書の関連内で絞る。
    # 件数と大きさの検証は、追加と取り外しを反映した最終的な添付に対して働く。
    #
    # Blob の実体は、取り外した関連のコミットが成功した後にだけ消える。
    def update_document_and_attachments
      attributes = document_params
      added = Array(attributes.delete(:attachments)).reject(&:blank?)
      removed = @document.attachments.where(id: remove_attachment_ids)

      Document.transaction(requires_new: true) do
        removed.each(&:destroy)
        @document.assign_attributes(attributes)
        @document.attachments.attach(added) if added.any?
        @document.save!
      end

      true
    rescue ActiveRecord::RecordInvalid
      restore_edit_screen(attributes)
      false
    end

    # 巻き戻した途中状態を編集画面へ持ち込まない。
    # そのまま描画すると、実際には残っている添付が画面から消えて見える。
    #
    # reload で DB 上の文書と添付へ戻したうえで、検証エラーと、入力されたスカラー属性だけを
    # 表示のために復元する。部門の選択は表示専用の値として渡す。
    # 保存済みの文書へ部門を代入し直すと、描画のつもりの操作がその場で保存されてしまう。
    def restore_edit_screen(attributes)
      submitted_errors = @document.errors.map { |error| error }
      @selected_department_ids = Array(params.dig(:document, :department_ids)).reject(&:blank?).map(&:to_i)

      @document.reload
      @document.assign_attributes(attributes.except(:department_ids))
      @document.errors.clear
      submitted_errors.each { |error| @document.errors.import(error) }
    end

    def remove_attachment_ids
      Array(params.dig(:document, :remove_attachment_ids)).reject(&:blank?)
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
