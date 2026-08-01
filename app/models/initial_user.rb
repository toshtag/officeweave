# 導入直後の最初のひとり。
#
# 導入直後はログインできる利用者が存在しないため、最初のひとりだけをここで作る。
# 既に存在する場合は何もしない。繰り返し実行しても結果が変わらないようにする。
#
# 資格情報の既定値は用意しない。手順書に載る値をそのまま使える状態にすると、
# そのまま運用へ残る。値が無い場合は、推測せずに利用者を作らない。
#
# 与えられた値が最低要件を満たすかどうかは User の検証が決める。
# 満たさない場合は作成に失敗し、呼び出し元も失敗として終わる。
class InitialUser
  DEFAULT_NAME = "管理者".freeze

  def self.install(**attributes)
    new(**attributes).install
  end

  def initialize(organization_code:, organization_name:, email_address:, password:, name: nil)
    @organization_code = organization_code
    @organization_name = organization_name
    @email_address = email_address
    @password = password
    # Compose は未設定の変数を空文字で渡す。表示名だけは空欄を未設定と同じに扱う。
    # 資格情報とは違い、推測して困る値ではない。
    @name = name.presence || DEFAULT_NAME
  end

  # 何をしたかを返す。表示は呼び出し元が決める。
  # 実行した人へ何を伝えるかは、実行の経路ごとに違う。
  def install
    return :missing_credentials if @email_address.blank? || @password.blank?

    organization = find_or_create_organization

    # 判定は組織の中で閉じる。全体で見ると、2 つ目の組織を足したときに、
    # その組織へ誰もログインできない状態になる。組織は作られるため、
    # 一見成功したように見える。
    return :already_present if organization.users.exists?

    organization.users.create!(
      name: @name,
      email_address: @email_address,
      password: @password,
      # 最初のひとりは、他の利用者を作れる必要がある。
      role: :administrator
    )

    :created
  end

  private
    # 導入単位となる組織。既にある場合はそのまま使う。
    def find_or_create_organization
      Organization.find_or_create_by!(code: @organization_code) do |record|
        record.name = @organization_name
      end
    end
end
