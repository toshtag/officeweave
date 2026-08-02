# OfficeWeave 認証方式の差し替え

本書は、認証方式を外部の基盤へ差し替える手順を定義する。

既定は内部認証とする。外部の認証基盤を必須にしない。
セルフホストで、外部サービスへの接続を動作の前提にしないためである。

## 1. 差し替え口

認証は次の 3 つの呼び出しだけを通る。

```text
name_key           設定で指定する名前を返す
authenticate       資格情報から利用者を返す。該当しなければ nil を返す
password_required? 画面でパスワードの入力を求めるか
```

呼び出しをこれ以上増やさない。増やすほど、外部の方式を足す手間が上がる。

既定の実装は `app/models/authentication/internal_provider.rb` にある。

## 2. 追加する手順

1. 上記 3 つに応える実装を `app/models/authentication/` へ置く
2. `config/initializers/authentication_providers.rb` へ登録を追加する
3. 環境変数 `AUTHENTICATION_PROVIDER` へ `name_key` の値を指定する
4. `bin/diagnose` の「認証方式」で、意図した `name_key` が解決されていることを確かめる

```ruby
module Authentication
  class ExampleProvider
    def self.name_key = "example"

    def self.password_required? = false

    def self.authenticate(email_address:, password:)
      # 外部の基盤へ問い合わせ、対応する利用者を返す。
      # 該当しない場合と、無効にされた利用者の場合は nil を返す。
    end
  end
end
```

## 3. OIDC の検証

OIDC の id_token の検証は `app/models/authentication/oidc/id_token.rb` にある。
認可の開始と受け取りは、この文書の版では扱っていない。

検証で確かめるものは次のとおりである。

```text
署名        公開鍵の方式だけを認める。alg=none と共通鍵の方式は通らない
発行者      設定した OIDC_ISSUER と一致すること
宛先        OIDC_CLIENT_ID を含むこと
期限        exp を過ぎていないこと
発行時刻    iat が未来でないこと（30 秒までのずれは吸収する）
nonce       要求のときに作った値と一致すること
email       あること。email_verified の記載がある場合は true であること
sub         あること
```

仕様が任意としている `nonce` と `email` を必須にしている。
`nonce` は要求と応答の対応を確かめる唯一の手がかりであり、
`email` は利用者の突き合わせに使う。

署名の検証、期限の判定、鍵の選択は `jwt` へ委ねている。
委ねる範囲は `JWT.decode` の 1 か所に閉じている。

## 4. 認可サーバーとの通信

`app/models/authentication/oidc/client.rb` が扱う。

```text
発見    {OIDC_ISSUER}/.well-known/openid-configuration から端点と鍵の場所を読む
鍵      jwks_uri から署名の検証に使う鍵を読む
交換    token_endpoint へ code を送り、id_token を受け取る
```

相手の応答を信じる範囲は次のとおりである。

```text
- 名乗る issuer が OIDC_ISSUER と一致すること
- 端点が https で、同じ発行者の下にあること
- 3 つの端点（authorization、token、jwks）がそろっていること
- 転送（3xx）には従わない
- 受け取る量は 256 KiB まで。超えた時点で接続を切る
```

発見の結果は 1 時間だけ共有する。鍵を入れ替えた場合、反映されるまでに
最大 1 時間かかる。

`client_secret` は Basic 認証で送る。本文へは入れない。

## 5. 実装が守ること

- `name_key` は空でない識別子とし、先頭または末尾へ空白を含めない。
  不正な `name_key` は登録の時点で拒否する。取り除いて受理することはない
- `name_key` は他の方式と重複させない。同じ識別子を別の実装へ割り当てた場合は
  登録の時点で失敗する。登録順による上書きは行わない
- 該当する利用者がいない場合は `nil` を返す。例外を投げない
- 無効にされた利用者は認証しない
- 失敗の理由を呼び出し元へ区別して返さない。利用者の存在を確かめる手段になる
- 利用者の記録がまだない場合の扱い（自動で作るかどうか）は実装側で決める

## 4. 知らない名前が指定された場合

起動しない。内部認証へは落とさない。

落とすと、外部の基盤で利用者を統制している構成が、設定の誤記だけで
内部のパスワード認証として起動する。外部認証へ移行済みの組織では、
使わなくなったパスワードが古い値のまま再び有効になる。
記録を見るまで気付けない状態を作らない。

値は加工しない。前後の空白、大文字小文字、空文字はいずれも誤記として扱う。
似た名前も推測しない。設定そのものが無い場合だけ、内部認証を使う。

| 設定         | 起動       |
| ---------- | -------- |
| 未設定        | 内部認証     |
| `internal` | 内部認証     |
| 登録済みの名前    | 指定した方式   |
| 未登録の名前     | 起動しない    |
| 空文字        | 起動しない    |
| 空白だけ、または前後に空白を含む値 | 起動しない |

例外には、環境変数名、指定された値、利用可能な方式が載る。

```text
AUTHENTICATION_PROVIDER="oidc" は登録されていません。利用可能な認証方式: internal
```

判定は `config/initializers/authentication_providers.rb` が起動時に行う。
登録は必ずこの検査より前へ書く。検査より後へ書いた登録は間に合わない。

登録した後は `bin/diagnose` の「認証方式」で、解決された名前を確かめる。

## 5. 現時点で用意していないもの

外部の認証基盤に対応する実装は同梱していない。
差し替え口だけを用意し、必要になった時点で実装を足す。

同梱していない理由は、対応先ごとに必要な設定と検証が異なり、
使われないまま保守だけが必要になるためである。
