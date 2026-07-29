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

## 3. 実装が守ること

- 該当する利用者がいない場合は `nil` を返す。例外を投げない
- 無効にされた利用者は認証しない
- 失敗の理由を呼び出し元へ区別して返さない。利用者の存在を確かめる手段になる
- 利用者の記録がまだない場合の扱い（自動で作るかどうか）は実装側で決める

## 4. 知らない名前が指定された場合

内部認証へ落とし、記録へ残す。

認証できない状態で起動すると、誰も入れなくなる。
設定の誤りで組織全体が締め出されることを避ける。

## 5. 現時点で用意していないもの

外部の認証基盤に対応する実装は同梱していない。
差し替え口だけを用意し、必要になった時点で実装を足す。

同梱していない理由は、対応先ごとに必要な設定と検証が異なり、
使われないまま保守だけが必要になるためである。
