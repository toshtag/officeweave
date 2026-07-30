require "test_helper"

class WebhookEndpointTest < ActiveSupport::TestCase
  test "名前と URL があれば登録できる" do
    endpoint = organizations(:main).webhook_endpoints.new(name: "連携先", url: "https://example.com/hook")

    assert endpoint.valid?
  end

  test "署名に使う値が自動で作られる" do
    endpoint = organizations(:main).webhook_endpoints.create!(name: "連携先", url: "https://example.com/hook")

    assert endpoint.secret.present?
  end

  test "http または https 以外は登録できない" do
    endpoint = organizations(:main).webhook_endpoints.new(name: "連携先", url: "ftp://example.com/hook")

    assert_not endpoint.valid?
  end

  test "改行を挟んだ値は登録できない" do
    endpoint = organizations(:main).webhook_endpoints.new(name: "連携先", url: "https://example.com\nevil")

    assert_not endpoint.valid?
  end

  test "宛先のない URL は登録できない" do
    endpoint = organizations(:main).webhook_endpoints.new(name: "連携先", url: "https://")

    assert_not endpoint.valid?
  end

  test "署名は受け取る側で同じ計算になる" do
    endpoint = organizations(:main).webhook_endpoints.create!(name: "連携先", url: "https://example.com/hook")
    payload = '{"event":"announcement_published"}'

    expected = OpenSSL::HMAC.hexdigest("SHA256", endpoint.secret, payload)

    assert_equal expected, endpoint.signature_for(payload)
  end

  # --- 内部の宛先 ---

  test "私用アドレスを直接書いた宛先は登録できない" do
    %w[
      http://10.0.0.1/hook
      http://192.168.0.1/hook
      http://172.16.0.1/hook
      http://169.254.169.254/
    ].each do |url|
      endpoint = organizations(:main).webhook_endpoints.new(name: "連携先", url: url)

      assert_not endpoint.valid?, "#{url} が登録できてしまう"
      assert_includes endpoint.errors.details[:url].map { |detail| detail[:error] }, :destination_not_allowed
    end
  end

  test "ループバックの宛先は登録できない" do
    %w[http://127.0.0.1/hook http://[::1]/hook http://localhost/hook].each do |url|
      endpoint = organizations(:main).webhook_endpoints.new(name: "連携先", url: url)

      assert_not endpoint.valid?, "#{url} が登録できてしまう"
    end
  end

  test "許可されていないポートは登録できない" do
    endpoint = organizations(:main).webhook_endpoints.new(name: "連携先", url: "http://example.com:8080/hook")

    assert_not endpoint.valid?
    assert_includes endpoint.errors.details[:url].map { |detail| detail[:error] }, :port_not_allowed
  end

  test "資格情報や # を含む URL は登録できない" do
    endpoint = organizations(:main).webhook_endpoints.new(name: "連携先", url: "https://user:pass@example.com/hook")
    assert_not endpoint.valid?

    endpoint = organizations(:main).webhook_endpoints.new(name: "連携先", url: "https://example.com/hook#part")
    assert_not endpoint.valid?
  end

  test "解決できないホスト名は登録できない" do
    endpoint = organizations(:main).webhook_endpoints.new(name: "連携先", url: "https://example.invalid/hook")

    assert_not endpoint.valid?
    assert_includes endpoint.errors.details[:url].map { |detail| detail[:error] }, :resolution_failed
  end

  test "拒否の理由が日本語と英語で読める" do
    endpoint = organizations(:main).webhook_endpoints.new(name: "連携先", url: "http://10.0.0.1/hook")
    endpoint.valid?

    I18n.with_locale(:ja) do
      assert_match(/内部/, endpoint.errors.full_messages_for(:url).join)
    end

    endpoint.errors.clear
    endpoint.valid?

    I18n.with_locale(:en) do
      assert_match(/internal/, endpoint.errors.full_messages_for(:url).join)
    end
  end

  # --- 再検証の範囲 ---

  test "URL を変えたときは検証をやり直す" do
    endpoint = organizations(:main).webhook_endpoints.create!(name: "連携先", url: "https://example.com/hook")

    endpoint.url = "http://10.0.0.1/hook"

    assert_not endpoint.valid?
  end

  test "停止中から有効へ戻すときは検証をやり直す" do
    endpoint = organizations(:main).webhook_endpoints.create!(name: "連携先", url: "https://example.com/hook",
                                                             active: false)
    # 既に保存されている危険な宛先は自動で変えない。有効へ戻す時点で拒否する。
    endpoint.update_column(:url, "http://10.0.0.1/hook")

    assert_not endpoint.reload.update(active: true)
  end

  test "名前だけの変更では名前解決をやり直さない" do
    endpoint = organizations(:main).webhook_endpoints.create!(name: "連携先", url: "https://example.com/hook")
    # 解決できない宛先を、検証を通さずに書き込む。
    endpoint.update_column(:url, "https://example.invalid/hook")

    assert endpoint.reload.update(name: "名前を変えただけ"),
           "URL に触れない更新が名前解決の失敗で止まっている"
  end

  test "停止する操作では名前解決をやり直さない" do
    endpoint = organizations(:main).webhook_endpoints.create!(name: "連携先", url: "https://example.com/hook")
    endpoint.update_column(:url, "https://example.invalid/hook")

    assert endpoint.reload.update(active: false)
  end
end
