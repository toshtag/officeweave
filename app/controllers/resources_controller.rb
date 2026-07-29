# 設備・備品の参照と管理。
# 参照は全員に開き、変更は管理者へ限定する。
class ResourcesController < ApplicationController
  before_action :require_administrator, only: %i[new create edit update]
  before_action :set_resource, only: %i[show edit update]

  def index
    @resources = current_organization.resources.ordered
  end

  def show
  end

  def new
    @resource = current_organization.resources.new
  end

  def edit
  end

  def create
    @resource = current_organization.resources.new(resource_params)

    if @resource.save
      redirect_to @resource, notice: t("resources.created")
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @resource.update(resource_params)
      redirect_to @resource, notice: t("resources.updated")
    else
      render :edit, status: :unprocessable_content
    end
  end

  private
    def set_resource
      @resource = current_organization.resources.find(params[:id])
    end

    def resource_params
      params.expect(resource: %i[name code description capacity reservable position])
    end
end
