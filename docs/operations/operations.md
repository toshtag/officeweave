# OfficeWeave 運用

本書は、導入後の日常的な運用を定義する。

本書のコマンドは、すべて配布用の構成に対して実行する。
Compose を呼び出すコマンドには必ず `-f compose.production.yaml` を付ける。
付け忘れると、開発用の構成に対して実行される。

## 1. 利用者の管理

利用者の追加、更新、無効化は、管理者が画面から行う。

- 退職や異動では、削除せず無効化する。過去の申請や監査の記録からたどれなくなる
- 無効化すると、進行中のセッションもその場で終わる
- 権限は「管理者」と「一般利用者」の 2 段階のみ

まとめて登録する場合は CSV の取り込みを使う。

```bash
docker compose -f compose.production.yaml exec web bin/rails runner "puts UserCsv::HEADERS.join(',')"
```

取り込みは 1 行でも誤りがあると何も保存しない。行番号と理由が画面に出る。

## 2. 組織構造の変更

部門の追加、名称の変更、階層の変更は管理者が行う。

- 下位部門を持つ部門は削除できない。先に下位を移すか削除する
- 部門を削除すると、その部門への所属も取り除かれる
- 部門を公開範囲に指定しているお知らせ、予定、文書がある場合、削除前に見直す

## 3. 監視

### 稼働の確認

| 経路        | 用途                    | 期待する応答                |
| --------- | --------------------- | --------------------- |
| `/up`     | コンテナの再起動判定            | 200                   |
| `/health` | 監視と通報                 | 200、依存先に問題があれば 503    |

再起動判定に `/health` を使わない。
データベースの一時的な不調で、アプリケーションが再起動を繰り返す。

### 記録

```bash
docker compose -f compose.production.yaml logs -f web
```

```bash
docker compose -f compose.production.yaml logs -f db
```

```bash
docker compose -f compose.production.yaml logs -f worker
```

記録の保管と回収は、組織の環境にある仕組みへ委ねている。

### 送信の状況

メールと Webhook は worker が送る。溜まっていないか、失敗が残っていないかを確認する。

```bash
docker compose -f compose.production.yaml exec -T web bin/jobs_status
```

```bash
docker compose -f compose.production.yaml exec -T web bin/jobs_status --failed
```

worker が止まっていると、送信は行われずジョブが溜まる。データは失われない。
`bin/diagnose` は worker の不在を失敗として報告する。

## 4. 監査

重要な操作は監査記録として残る。管理者は画面から参照できる。

記録は書き足すだけで、更新も削除もできない。
保存期間の管理は用意していない。件数が問題になる場合は、
バックアップを取得したうえで、古い記録の扱いを検討する。

## 5. 定期的に行うこと

| 頻度   | 内容                                       |
| ---- | ---------------------------------------- |
| 毎日   | バックアップの取得（利用者側の時刻起動などで自動化する）             |
| 毎月   | `bin/diagnose` の実行、無効化し忘れた利用者の確認、失敗したジョブの確認 |
| 四半期  | バックアップからの復元の確認、依存の更新の確認                  |
| 随時   | セキュリティ修正の適用                              |

## 6. 困ったとき

### ログインできない

```bash
docker compose -f compose.production.yaml exec web bin/diagnose
```

有効な管理者が存在するかを確認する。
いない場合は、`.env` を設定したうえで `bin/rails db:seed` を実行する。

### 通知が届かない

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

### 添付ファイルが開けない

バックアップから復元した際に、ファイルの保存先が戻っていない可能性がある。
バックアップにはデータベースとファイルの両方が含まれる。書庫の内容を確認する。

### 予約が重なって登録されてしまう

登録できない仕組みになっている。登録できた場合はデータベース側の制約が
失われている可能性があるため、`bin/diagnose` で拡張機能の状態を確認する。
