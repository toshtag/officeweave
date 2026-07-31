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
  end

  test "既知の初期値は表記を変えても拒む" do
    [ "change_me", "CHANGE_ME", " change_me ", "password", "PASSWORD", "officeweave" ].each do |value|
      assert Authentication::PasswordPolicy.known_unsafe?(value), "#{value.inspect} を見逃した"
      assert_equal :known_unsafe, Authentication::PasswordPolicy.violation(value)
    end
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
