require "test_helper"

class LocaleNegotiationTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:taro) }

  test "指定がなければ既定の言語で表示する" do
    get root_url

    assert_select "html[lang=?]", "ja"
  end

  test "ブラウザーが希望する言語のうち、対応しているものを選ぶ" do
    get root_url, headers: { "HTTP_ACCEPT_LANGUAGE" => "en-US,en;q=0.9" }

    assert_select "html[lang=?]", "en"
  end

  test "対応していない希望だけの場合は既定の言語へ落とす" do
    get root_url, headers: { "HTTP_ACCEPT_LANGUAGE" => "fr-FR,fr;q=0.9" }

    assert_select "html[lang=?]", "ja"
  end

  test "画面での選択はブラウザーの希望より優先される" do
    patch locale_url, params: { locale: "ja", return_to: root_path }

    get root_url, headers: { "HTTP_ACCEPT_LANGUAGE" => "en-US,en;q=0.9" }

    assert_select "html[lang=?]", "ja"
  end
end
