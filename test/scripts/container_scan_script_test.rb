require "test_helper"

# 配布するイメージの脆弱性検査の契約を固定する。
#
# 依存の監査は Gemfile.lock を見る。イメージへ入っている OS のパッケージは
# 見ない。配布しているのはイメージであり、そこに含まれるものすべてが対象で
# ある。
#
# 実際に走らせて確かめない。検査は脆弱性のデータベースを取得するため、
# 実行のたびに結果が変わる。確かめたいのは検査の条件であり、そのときの
# 指摘の件数ではない。
class ContainerScanScriptTest < ActiveSupport::TestCase
  SCRIPT = Rails.root.join("script/scan_container_image").freeze
  WORKFLOW = Rails.root.join(".github/workflows/verify.yml").freeze
  VERIFY = Rails.root.join("config/verify.rb").freeze
  REPORT_DIR = "scan_report".freeze

  setup do
    @body = SCRIPT.read
  end

  test "検査のコマンドがある" do
    assert SCRIPT.exist?, "script/scan_container_image が無い"
    assert SCRIPT.executable?, "実行できない"
  end

  # 検査器の中身が後から変わると、同じ commit を検査しても結果が変わる。
  test "検査器を digest で固定する" do
    assert_match(/aquasec\/trivy:[0-9.]+@sha256:[0-9a-f]{64}/, @body,
                 "検査器が digest で固定されていない")
  end

  test "配布用のイメージを対象にする" do
    assert_match(/Dockerfile\.production/, @body)
  end

  # 名前を書き写すと、構成の側を上げたときに古い版を検査し続ける。
  test "データベースのイメージ名を構成から読む" do
    assert_match(/compose\.production\.yaml/, @body)
    assert_no_match(/postgres:[0-9]/, @body, "イメージ名を書き写している")
  end

  test "重大さの下限を持つ" do
    assert_match(/--severity/, @body)
    assert_match(/HIGH,CRITICAL/, @body)
  end

  # 修正版が出ていない指摘で失敗させると、自分たちで解消できない状態で
  # 検証が止まり続ける。
  test "修正版のある指摘で失敗する" do
    assert_match(/--ignore-unfixed/, @body)
    assert_match(/--exit-code[= ]1/, @body)
  end

  # 失敗させないことと、見せないことは別である。
  test "修正版のない指摘も報告へ残す" do
    assert_match(/--exit-code[= ]0/, @body)
    assert_match(/#{Regexp.escape(REPORT_DIR)}/, @body)
  end

  # 実行のたびに変わるものを追跡すると、差分が読めなくなる。
  test "報告をリポジトリへ含めない" do
    assert_match(/^#{Regexp.escape(REPORT_DIR)}\/$/, Rails.root.join(".gitignore").read)
  end

  # 組み立てるイメージは入れるパッケージを選べる。取り込むイメージへの手立ては
  # tag を上げることだけで、上げても解消しない場合がある。解消できない指摘で
  # 検証を止め続けると、失敗を無視する習慣がつく。
  test "合否を決めるのは組み立てたイメージだけとする" do
    assert_match(/scan_and_gate "配布用のイメージ"/, @body)
    assert_match(/scan_and_report "データベースのイメージ"/, @body)
  end

  test "継続的インテグレーションが報告を残す" do
    assert_match(/#{Regexp.escape(REPORT_DIR)}/, WORKFLOW.read)
  end

  # socket を渡すと、検査器がホストの Docker を操作できる。
  # 検査するだけなら、書き出した内容を読ませれば足りる。
  test "Docker の socket を渡さない" do
    assert_no_match(%r{/var/run/docker\.sock}, @body)
    assert_match(/docker save/, @body)
  end

  # root で動かすと、置いていった脆弱性のデータベースをホスト側で消せず、
  # 後片付けが失敗する。ファイルの持ち主は実行環境によって変わる。
  test "検査器をホストの利用者として動かす" do
    assert_match(/--user "\$\(id -u\):\$\(id -g\)"/, @body)
  end

  # 置いていくと、次の実行が同じ名前で組み立て直し、前の内容が参照されない
  # まま残る。検査は繰り返し実行するため、実行の回数だけ溜まる。
  test "組み立てたイメージを後片付けする" do
    assert_match(/trap '[^']*docker rmi "\$APP_IMAGE"[^']*' EXIT/, @body,
                 "組み立てたイメージを EXIT で取り除いていない")
  end

  # 脆弱性のデータベースは日々変わる。一括検証は実行のたびに同じ結果になる
  # ことを条件にしているため、そこへは含めない。
  test "一括検証へ含めない" do
    assert_no_match(/scan_container_image/, VERIFY.read)
  end

  test "継続的インテグレーションが検査を実行する" do
    assert_match(/script\/scan_container_image/, WORKFLOW.read)
  end
end
