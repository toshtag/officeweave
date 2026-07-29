module NavigationHelper
  # 見出し領域に並べる移動先。
  # 権限で表示が変わるため、画面ごとに書かずここで組み立てる。
  def navigation_items
    items = [
      { name: t("home.title"), path: root_path },
      { name: t("departments.index.heading"), path: departments_path }
    ]

    items << { name: t("users.index.heading"), path: users_path } if administrator?
    items
  end

  # 現在いる画面かどうか。読み上げにも現在位置を伝えるため、表示だけで示さない。
  def current_navigation_item?(path)
    path == root_path ? request.path == path : request.path.start_with?(path)
  end
end
