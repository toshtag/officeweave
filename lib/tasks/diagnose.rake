# 運用時の構成を確認する。
#
# 起動しただけでは分からない不備を、導入直後とアップグレード後に洗い出す。
namespace :officeweave do
  desc "構成と依存先の状態を確認する"
  task diagnose: :environment do
    checks = Diagnostics.new.run
    failures = checks.count { |check| check[:status] == :error }
    warnings = checks.count { |check| check[:status] == :warning }

    checks.each do |check|
      mark = { ok: "OK  ", warning: "注意", error: "失敗" }.fetch(check[:status])
      puts "#{mark}  #{check[:name]}"
      puts "      #{check[:detail]}" if check[:detail].present?
    end

    puts
    puts "確認 #{checks.size} 件、注意 #{warnings} 件、失敗 #{failures} 件"

    # 失敗がある状態で 0 を返すと、自動実行で見落とす。
    exit(1) if failures.positive?
  end
end
