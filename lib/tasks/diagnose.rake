# 運用時の構成を確認する。
#
# 起動しただけでは分からない不備を、導入直後とアップグレード後に洗い出す。
#
# 出力の組み立てと合否の判定は DiagnosticsOutput が持つ。ここへ置くと、
# 形と終了状態を確かめるために毎回コマンドを起動することになる。
namespace :officeweave do
  desc "構成と依存先の状態を確認する"
  task diagnose: :environment do
    output = DiagnosticsOutput.new(Diagnostics.new.run)

    output.lines.each { |line| puts line }

    exit(1) if output.failed?
  end
end
