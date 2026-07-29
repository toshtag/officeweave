require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "入口の画面が表示される" do
    get root_url

    assert_response :success
    assert_select "h1", I18n.t("home.heading")
  end

  test "題名に画面名と製品名が含まれる" do
    get root_url

    assert_select "title", "#{I18n.t('home.title')} - #{I18n.t('application.name')}"
  end

  test "文書の言語が既定の言語で示される" do
    get root_url

    assert_select "html[lang=?]", "ja"
  end
end
