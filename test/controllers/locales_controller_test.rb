require "test_helper"

class LocalesControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:taro) }

  test "選んだ言語が以降の要求へ引き継がれる" do
    patch locale_url, params: { locale: "en", return_to: root_path }

    assert_redirected_to root_path

    get root_url
    assert_select "html[lang=?]", "en"
    assert_select "h1", I18n.t("home.heading", locale: :en)
  end

  test "対応していない言語は無視される" do
    patch locale_url, params: { locale: "fr", return_to: root_path }

    get root_url
    assert_select "html[lang=?]", "ja"
  end

  test "元の画面へ戻る" do
    patch locale_url, params: { locale: "en", return_to: "/health" }

    assert_redirected_to "/health"
  end

  test "外部サイトへの誘導を受け付けない" do
    patch locale_url, params: { locale: "en", return_to: "https://example.invalid/" }
    assert_redirected_to root_path

    patch locale_url, params: { locale: "en", return_to: "//example.invalid/" }
    assert_redirected_to root_path
  end

  test "言語の切り替えは GET では受け付けない" do
    get "/locale?locale=en"

    assert_response :not_found
  end
end
