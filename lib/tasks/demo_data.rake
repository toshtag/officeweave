# 動作確認用のデータを投入する。
#
# 実在する個人や組織の情報は使わない。すべて架空の値とする。
# 本番環境では実行しない。既存のデータと混ざると区別が付かなくなる。
namespace :officeweave do
  desc "動作確認用のデータを投入する"
  task demo_data: :environment do
    if Rails.env.production? && ENV["ALLOW_DEMO_DATA"] != "1"
      abort("本番環境では実行しません。実行する場合は ALLOW_DEMO_DATA=1 を指定してください。")
    end

    result = DemoData.new.install

    puts "投入しました。"
    result.each { |name, count| puts "  #{name}: #{count} 件" }
    puts
    puts "ログインに使える利用者:"
    DemoData::USERS.each do |user|
      puts "  #{user[:email_address]} / #{DemoData::PASSWORD}（#{user[:name]}）"
    end
  end
end
