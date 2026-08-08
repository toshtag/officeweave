# 困ったとき

運用中に出る症状と、その調べ方をまとめます。
入れ替えの失敗は [アップグレード](upgrade.md#3-失敗した場合)、
復元の失敗は [バックアップと復元](backup.md#復元に失敗した場合) にあります。

## ログインできない

```bash
docker compose -f compose.production.yaml exec web bin/diagnose
```

有効な管理者が存在するかを確認する。
いない場合は、`.env` を設定したうえで `script/seed_initial_user` を実行する。

## すぐにログイン画面へ戻される

ログイン状態は、無操作 30 分か、ログインから 8 時間で終わる。
どちらか一方でも超えると、記録と Cookie の両方を破棄してログイン画面へ戻す。
想定どおりの動作であり、あらためてログインする。

`SECRET_KEY_BASE` を変えた直後も、進行中のセッションはすべて無効になる。

## 403 が返る

要求の `Host` が `APPLICATION_HOST` と一致していない。

```bash
docker compose -f compose.production.yaml exec web sh -c 'echo "${APPLICATION_HOST}"'
```

`.env` の値と、利用者が実際に接続しているホスト名を突き合わせる。
逆プロキシを使う場合は、元の `Host` をそのまま転送しているかを確認する。
書き換えている場合は、転送後の値を `APPLICATION_HOST` に合わせる。

値を変えたら web を再起動する。

## 通知が届かない

送信設定が有効かどうかを診断で確認する。
利用者側で、その種類の通知を受け取らない設定にしている場合もある。

worker が動いているかも確認する。止まっていると送信は行われない。

```bash
docker compose -f compose.production.yaml exec -T web bin/jobs_status
```

やり直しを尽くして失敗した送信は残る。理由を確認する。

```bash
docker compose -f compose.production.yaml exec -T web bin/jobs_status --failed
```

同じ通知が二度届く場合もある。実行は at-least-once であり、
送信サーバーが受理した直後の切断では重複を防げない。
Webhook では `X-OfficeWeave-Delivery-Id` で受け取る側が重複を判別できる。

## 添付ファイルが開けない

バックアップから復元した際に、ファイルの保存先が戻っていない可能性がある。
バックアップにはデータベースとファイルの両方が含まれる。書庫の内容を確認する。

添付ファイルは文書の配下の経路（`/documents/:id/attachments/:id`）からだけ取得できる。
ログインしていない場合はログイン画面へ移り、文書を参照できない場合は見つからない扱いになる。
`/rails/active_storage/` で始まる URL は用意していないため、
外部の資料や古い控えにその形の URL がある場合は、文書の画面から取り直す。

## 予約が重なって登録されてしまう

登録できない仕組みになっている。登録できた場合はデータベース側の制約が
失われている可能性があるため、`bin/diagnose` で拡張機能の状態を確認する。
