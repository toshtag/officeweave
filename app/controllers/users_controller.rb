# 管理者による利用者の管理。
class UsersController < ApplicationController
  before_action :require_administrator
  before_action :set_user, only: %i[edit update]

  def index
    @users = current_organization.users.ordered.includes(:primary_department)
  end

  def new
    @user = current_organization.users.new
  end

  def edit
  end

  def create
    @user = current_organization.users.new(user_params)

    if @user.save
      record_audit_event("user_created", target: @user, details: { email_address: @user.email_address })
      redirect_to users_path, notice: t("users.created")
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @user.update(user_params_for_update)
      record_audit_event("user_updated", target: @user, details: { email_address: @user.email_address })
      redirect_to users_path, notice: t("users.updated")
    else
      render :edit, status: :unprocessable_content
    end
  end

  private
    def set_user
      @user = current_organization.users.find(params[:id])
    end

    def user_params
      params.expect(user: %i[name email_address password password_confirmation role locale])
    end

    # パスワードは入力があったときだけ変更する。
    # 空のまま送信された場合に消してしまうと、利用者がログインできなくなる。
    def user_params_for_update
      attributes = user_params

      if attributes[:password].blank?
        attributes.except(:password, :password_confirmation)
      else
        attributes
      end
    end
end
