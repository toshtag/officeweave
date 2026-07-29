class ApplicationMailer < ActionMailer::Base
  # 送信元は環境変数で与える。config/initializers/mail_delivery.rb で設定している。
  layout "mailer"
end
