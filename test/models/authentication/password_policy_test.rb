require "test_helper"

class Authentication::PasswordPolicyTest < ActiveSupport::TestCase
  test "最低長は 15 文字とする" do
    assert_equal 15, Authentication::PasswordPolicy::MINIMUM_LENGTH
  end

  test "未入力は判定の対象にしない" do
    assert_nil Authentication::PasswordPolicy.violation(nil)
    assert_nil Authentication::PasswordPolicy.violation("")
  end

  test "最低長に満たない値は短いとして返す" do
    assert_equal :too_short, Authentication::PasswordPolicy.violation("a")
    assert_equal :too_short, Authentication::PasswordPolicy.violation("abcdefghijklmn")
  end

  test "最低長を満たせば小文字だけの値も受理する" do
    assert_nil Authentication::PasswordPolicy.violation("abcdefghijklmno")
  end

  test "長さは文字数で数える" do
    assert_equal :too_short, Authentication::PasswordPolicy.violation("あいうえおかきくけこさしすせ")
    assert_nil Authentication::PasswordPolicy.violation("あいうえおかきくけこさしすせそ")
  end

  test "空白を含むことを理由に拒まない" do
    assert_nil Authentication::PasswordPolicy.violation("a long secret value")
    assert_nil Authentication::PasswordPolicy.violation("#{'a' * 14} ")
  end

  # has_secure_password は空文字でない値なら digest を作る。
  # 空白だけの値は、長さを満たしていても新しいパスワードとして受け取らない。
  test "空白だけの値は長さを満たしていても拒む" do
    [ " " * 15, "\t" * 15, "　" * 15, " " * 20 ].each do |value|
      assert_equal :blank, Authentication::PasswordPolicy.violation(value), "#{value.inspect} を受理した"
    end
  end

  test "空白だけの値は長さを理由にしない" do
    assert_equal :blank, Authentication::PasswordPolicy.violation(" ")
  end

  test "既知の初期値は表記を変えても拒む" do
    [ "change_me", "CHANGE_ME", " change_me ", "password", "PASSWORD", "officeweave" ].each do |value|
      assert Authentication::PasswordPolicy.known_unsafe?(value), "#{value.inspect} を見逃した"
      assert_equal :known_unsafe, Authentication::PasswordPolicy.violation(value)
    end
  end

  # 前後の空白を無視する範囲は、空白だけの判定と同じでなければならない。
  # 食い違うと、片方だけが認める空白で既知の値を囲んで迂回できる。
  test "既知の初期値を Unicode の空白で囲んでも拒む" do
    [
      "\u3000\u3000officeweave\u3000\u3000",                   # 全角空白
      "\u00A0\u00A0password\u00A0\u00A0\u00A0\u00A0\u00A0", # ノーブレークスペース
      "\u2003\u2003\u2003change_me\u2003\u2003\u2003",       # EM SPACE
      "   Officeweave    ",                                    # ASCII 空白と大文字小文字
      "\r\n\r\npassword\r\n\r\n\r\n"                     # 改行
    ].each do |value|
      assert_operator value.length, :>=, Authentication::PasswordPolicy::MINIMUM_LENGTH,
                      "#{value.inspect} が最低長に満たない"
      assert Authentication::PasswordPolicy.known_unsafe?(value), "#{value.inspect} を見逃した"
      assert_equal :known_unsafe, Authentication::PasswordPolicy.violation(value)
    end
  end

  # 取り除くのは前後だけとする。内部の空白は値の一部である。
  test "内部の空白を取り除いたうえで既知の初期値と比べない" do
    [
      "office\u3000weave-is-safe",
      "my\u00A0password-is-long",
      "change\u2003_me-is-not-known"
    ].each do |value|
      assert_not Authentication::PasswordPolicy.known_unsafe?(value), "#{value.inspect} を拒んだ"
      assert_nil Authentication::PasswordPolicy.violation(value)
    end
  end

  # 判定のためだけに取り除く。保存するのは入力された値そのものである。
  test "既知の初期値と比べても元の値を変えない" do
    value = "\u3000OfficeWeave\u3000"
    original = value.dup

    Authentication::PasswordPolicy.known_unsafe?(value)
    Authentication::PasswordPolicy.violation(value)

    assert_equal original, value
  end

  test "既知の初期値を部分として含むだけの値は拒まない" do
    [ "officeweave-is-not-the-password", "my-password-is-long" ].each do |value|
      assert_not Authentication::PasswordPolicy.known_unsafe?(value), "#{value.inspect} を拒んだ"
      assert_nil Authentication::PasswordPolicy.violation(value)
    end
  end

  test "既知の初期値は長さより先に理由とする" do
    assert_equal :known_unsafe, Authentication::PasswordPolicy.violation("change_me")
  end

  test "判定した値そのものを変えない" do
    value = " Change_Me "

    Authentication::PasswordPolicy.violation(value)

    assert_equal " Change_Me ", value
  end

  test "文字列でない値は既知の初期値として扱わない" do
    assert_not Authentication::PasswordPolicy.known_unsafe?(nil)
    assert_not Authentication::PasswordPolicy.known_unsafe?(:change_me)
  end
end
