require "test_helper"

# 実ブラウザーでの検証の組み方を固定する。
#
# ブラウザーを使う層を足すと、既定の検証がその環境に依存し得る。依存させない
# 組み方と、外した範囲を必ず実行する仕組みを、ここで固定する。
class BrowserVerificationTest < ActiveSupport::TestCase
  BROWSER_COMPOSE = Rails.root.join("compose.browser.yaml").freeze
  VERIFY = Rails.root.join("config/verify.rb").freeze
  # 仕事の置き場所は 1 つに限らない。ファイルの名前ではなく、継続的
  # インテグレーションのどこかで実行されることを確かめる。名前で指すと、
  # 仕事を移しただけで、実行されなくなったのと同じ失敗になる。
  WORKFLOWS = Rails.root.glob(".github/workflows/*.yml").map(&:read).join("\n").freeze
  SYSTEM_TEST_CASE = Rails.root.join("test/application_system_test_case.rb").freeze
  BROWSER_TEST_CASE = Rails.root.join("test/browser_test_case.rb").freeze

  test "既定のシステムテストはブラウザーを使わない" do
    # ブラウザーを既定にすると、すべてのテストがその環境を要する。
    assert_match(/driven_by :rack_test/, SYSTEM_TEST_CASE.read)
  end

  test "ブラウザーは別の service として置く" do
    assert BROWSER_COMPOSE.exist?, "compose.browser.yaml が無い"
    assert_match(/^\s+browser:/, BROWSER_COMPOSE.read)
  end

  # 中身が後から変わると、同じ commit を検証しても結果が変わる。
  test "ブラウザーの版を digest で固定する" do
    assert_match(/image: \S+@sha256:[0-9a-f]{64}/, BROWSER_COMPOSE.read)
  end

  test "開発用のイメージへブラウザーを入れない" do
    # イメージの大きさと組み立て時間が増え、実行環境が利用者の環境から離れる。
    assert_no_match(/chrom/i, Rails.root.join("Dockerfile").read)
    assert_no_match(/chrom/i, Rails.root.join("Dockerfile.production").read)
  end

  # 一括検証は、追加の道具なしで手元で実行できる状態を保つ。
  test "一括検証はブラウザーを要する層を外す" do
    assert_match(/test:except_browser/, VERIFY.read)
    assert_no_match(/test:all/, VERIFY.read)
  end

  # 外していることを黙って済ませない。
  test "継続的インテグレーションがブラウザーの層を実行する" do
    assert_match(/test:browser/, WORKFLOWS)
    assert_match(/compose\.browser\.yaml/, WORKFLOWS)
  end

  test "ブラウザーへ渡す宛先を実行環境から受け取る" do
    # ブラウザーは別のコンテナで動く。localhost では届かない。
    assert_match(/SELENIUM_REMOTE_URL/, BROWSER_TEST_CASE.read)
    assert_match(/BROWSER_TEST_APPLICATION_HOST/, BROWSER_TEST_CASE.read)
    assert_match(/server_host = "0\.0\.0\.0"/, BROWSER_TEST_CASE.read)
  end

  # 表示する言語が実行環境で決まると、同じ画面で別の文言を見ることになる。
  test "ブラウザーの言語を固定する" do
    assert_match(/--lang=ja/, BROWSER_TEST_CASE.read)
  end
end
