module Authentication
  # 遷移先として認める経路の判定。
  #
  # 認めるのは、アプリケーション内の絶対パスだけとする。
  # クエリ文字列は含めてよい。スキーム、ホスト、ポート、フラグメントは含めない。
  #
  #   Authentication::LocalPath.permitted("/documents?query=manual")  # => "/documents?query=manual"
  #   Authentication::LocalPath.permitted("//outside.example/path")   # => nil
  #
  # 値を保存する側と、遷移に使用する側の両方から呼ぶ。
  # 片方だけを検査すると、別の経路で書き込まれた値と、
  # 検査を入れる前に保存された値が、そのまま遷移先になる。
  module LocalPath
    # 改行を含む値は応答ヘッダーを壊す。
    CONTROL_CHARACTERS = /[[:cntrl:]]/

    class << self
      # 認められない場合は nil を返す。呼ぶ側は既定の遷移先へ落とす。
      def permitted(candidate)
        return nil unless candidate.is_a?(String)
        return nil unless candidate.start_with?("/")
        # //outside.example は上位プロトコル相対の URL として解釈される。
        return nil if candidate.start_with?("//")
        # 逆斜線は、ブラウザーの URL 解釈で斜線と同じに扱われる。
        # /\outside.example は //outside.example と同じ意味になる。
        return nil if candidate.include?("\\")
        return nil if candidate.match?(CONTROL_CHARACTERS)

        uri = URI.parse(candidate)
        return nil if uri.scheme || uri.host || uri.fragment

        candidate
      rescue URI::InvalidURIError
        # 解釈できない値は拒否する。例外を上げると、遷移先の指定だけで応答が壊れる。
        nil
      end
    end
  end
end
