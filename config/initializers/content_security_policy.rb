# 配信する内容の出所の制限。
#
# この製品はブラウザーへスクリプトを配信しない（R9-T1 で配信の基盤を外した）。
# 持ち込まれたスクリプトを実行しないことを、応答の側から宣言する。
#
# 宣言だけでは防げないものもある。出力の組み立て（平文としての描画）は
# それ自体で守る必要があり、これはその上に重ねる 1 枚である。
#
# 報告だけの設定にはしない。報告だけでは、実際に読み込まれるものが変わらない。
Rails.application.configure do
  config.content_security_policy do |policy|
    # 既定は自分の出所だけとする。挙げていない種類はここへ落ちる。
    policy.default_src :self

    # スクリプトは配信しない。配信していないものを実行できる余地を残さない。
    policy.script_src :none

    # 様式は自分の出所から配信する。埋め込みの様式は使っていない。
    policy.style_src :self

    # 画像は自分の出所と、埋め込みの data だけとする。
    policy.img_src :self, :data

    # 送信先を自分だけに限る。入力した内容が別の宛先へ送られる形を防ぐ。
    policy.form_action :self

    # 枠へ埋め込ませない。操作を上から覆う形を防ぐ。
    policy.frame_ancestors :none

    # 相対の解決の基準を、応答の出所へ固定する。
    policy.base_uri :self

    # 埋め込みの対象（object、embed）は使っていない。
    policy.object_src :none

    # 外部への接続は行わない。画面から出ていく通信を持たない。
    policy.connect_src :self
    policy.font_src :self
  end

  # 報告先は設定しない。外部へ送る宛先を、動作の前提にしない。
  config.content_security_policy_report_only = false
end
