class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy

  # 大文字小文字と前後の空白の違いで別の利用者として扱わない。
  normalizes :email_address, with: ->(value) { value.strip.downcase }

  validates :name, presence: true, length: { maximum: 100 }
  validates :email_address, presence: true, length: { maximum: 255 },
                            format: { with: URI::MailTo::EMAIL_REGEXP }

  # 表示言語の設定。未設定の場合は要求ごとの判定に従う。
  validates :locale, inclusion: { in: ->(_) { I18n.available_locales.map(&:to_s) } },
                     allow_nil: true
end
