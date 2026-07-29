module ApplicationHelper
  # 画面ごとの見出しと製品名を組み合わせて題名にする。
  # 各画面で題名の組み立て方を書くと、区切り文字や順序がばらつく。
  def page_title
    product_name = t("application.name")
    page_name = content_for(:title)

    page_name.present? ? "#{page_name} - #{product_name}" : product_name
  end
end
