require "test_helper"

# 負荷測定の契約を固定する。
#
# 応答の速さは動かす機械によって変わる。合否には使えないため、報告として残す。
# 測ったつもりで何も測っていない状態にならないことを、ここで固定する。
#
# 実際に走らせて確かめない。測定は起動している構成と、そこへ積んだデータを
# 前提にする。確かめたいのは測り方であり、そのときの速さではない。
class LoadMeasurementScriptTest < ActiveSupport::TestCase
  SCRIPT = Rails.root.join("script/measure_load").freeze
  VERIFY = Rails.root.join("config/verify.rb").freeze
  WORKFLOW = Rails.root.join(".github/workflows/verify.yml").freeze
  REPORT_DIR = "load_report".freeze

  setup do
    @body = SCRIPT.read
  end

  test "測定のコマンドがある" do
    assert SCRIPT.exist?, "script/measure_load が無い"
    assert SCRIPT.executable?, "実行できない"
  end

  # 中身が後から変わると、同じ commit を測っても結果が変わる。
  test "負荷をかける道具を digest で固定する" do
    assert_match(/oha:[0-9.]+@sha256:[0-9a-f]{64}/, @body, "道具が digest で固定されていない")
  end

  # 認証の後の画面を測る。ログイン画面を測り続けて速いという結果にしない。
  test "画面と同じ経路でログインする" do
    assert_match(%r{/session/new}, @body)
    assert_match(/csrf-token/, @body)
    assert_match(/ログインできませんでした/, @body)
  end

  test "資格情報を書き込まない" do
    # 測定のためだけの利用者であっても、値を手順へ埋め込まない。
    assert_match(/LOAD_MEASUREMENT_EMAIL:\?/, @body)
    assert_match(/LOAD_MEASUREMENT_PASSWORD:\?/, @body)
    assert_no_match(/password=[a-z-]+"/, @body, "パスワードを書き込んでいる")
  end

  # 読み込む量の違いが応答へ現れる画面を選ぶ。
  test "一覧と検索を測る" do
    %w[/announcements /events /documents /requests /users /audit_events].each do |path|
      assert_includes @body, %("#{path}")
    end

    assert_match(/documents\?query=/, @body)
  end

  # 200 以外が混ざっていれば、測った値は意味を持たない。
  test "応答の内容を確かめる" do
    assert_match(/statusCodeDistribution/, @body)
    assert_match(/測定は成立していません/, @body)
  end

  # 動かす機械によって変わる値で合否を決めない。
  test "速さで合否を決めない" do
    assert_no_match(/平均が|しきい値|threshold/i, @body)
    assert_match(/報告として残/, @body)
  end

  # 別の利用者で動かすと、ホスト側の作業ツリーへ書き込めない。
  test "道具をホストの利用者として動かす" do
    assert_match(/--user "\$\(id -u\):\$\(id -g\)"/, @body)
  end

  test "報告を書き出す" do
    assert_match(/#{Regexp.escape(REPORT_DIR)}/, @body)
    assert_match(/^#{Regexp.escape(REPORT_DIR)}\/$/, Rails.root.join(".gitignore").read)
  end

  # 起動している構成と積んだデータが要る。一括検証へは入れられない。
  test "一括検証へ含めない" do
    assert_no_match(/measure_load/, VERIFY.read)
  end

  test "継続的インテグレーションが測定を実行する" do
    assert_match(/script\/measure_load/, WORKFLOW.read)
  end

  test "測るためのデータを積む手順がある" do
    assert_match(/officeweave:load_sample/, @body)
  end
end
