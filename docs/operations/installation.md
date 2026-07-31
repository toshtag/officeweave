# OfficeWeave 導入手順

本書は、自組織の環境へ OfficeWeave を導入する手順を定義する。

## 1. 必要なもの

```text
Docker
Docker Compose
アプリケーションへ到達できるホスト名（運用環境）
メールを送信できる SMTP サーバー（通知を使う場合）
```

Ruby と PostgreSQL をホストへ導入する必要はない。すべてコンテナ内で動作する。

推奨する構成は、単一ホストでの運用である。
複数ホストでの構成は確認していない。

## 2. 取得

```bash
git clone https://github.com/toshtag/officeweave.git
```

```bash
cd officeweave
```

### 開発用と配布用の使い分け

本書の手順は、すべて配布用の構成に対して実行する。
そのため、Compose を呼び出すコマンドには必ず `-f compose.production.yaml` を付ける。

```bash
docker compose -f compose.production.yaml <コマンド>
```

付け忘れると、開発用の構成に対して実行される。
両者は project 名もデータボリュームも分けてあるため、
配布用のデータが壊れることはないが、意図した対象へは届かない。

## 3. 設定

```bash
cp .env.example .env
```

`.env` を編集する。運用環境では、少なくとも次を設定する。

```text
DATABASE_PASSWORD      推測されない値を設定する
INITIAL_USER_EMAIL     最初の管理者のメールアドレス
INITIAL_USER_PASSWORD  最初の管理者のパスワード
APPLICATION_HOST       利用者が接続するホスト名
SMTP_ADDRESS           通知をメールで送る場合
SECRET_KEY_BASE        署名に使う鍵
```

`.env.example` の秘密情報は空欄である。空欄のままでは構成を解決できず、起動しない。

設定できる項目の一覧は [設定](../development/configuration.md) にある。

### 最初の管理者の資格情報

初期利用者は `bin/rails db:seed` で作成する。作成する前に設定する。

```text
INITIAL_USER_EMAIL     必須。既定値はない
INITIAL_USER_PASSWORD  必須。既定値はない。15 文字以上とする
```

パスワードは 15 文字以上にする。大文字・数字・記号の混在は求めない。
`change_me`、`password`、`officeweave` は、表記を変えても使用できない。
要件を満たさない値を設定した場合、`bin/rails db:seed` は失敗し、利用者を作らない。

実際に設定した値を、コマンドの例や作業記録へ書き写さない。
本書と `.env.example` に載る値は、いずれも使用できない値である。

初期利用者の作成後は、`INITIAL_USER_PASSWORD` を環境から取り除いてよい。
設定に残った既知の初期値と、その値をそのまま使っている管理者は、
`bin/diagnose` が注意として知らせる。

### 接続するホスト名

公開する前に `APPLICATION_HOST` を必ず設定する。
運用環境では、ここに書いた 1 つのホスト名だけを受け入れ、
それ以外の `Host` を持つ要求は 403 で拒否する。

```text
正: officeweave.example.com
正: [2001:db8::10]
誤: https://officeweave.example.com/
誤: [fe80::1%eth0]
```

スキーム、経路、ポートは含めない。
逆プロキシの背後へ置く場合は、利用者が接続するホスト名を書く。
逆プロキシが `Host` を書き換える構成では、転送される値と一致させる。

値は起動時に検査する。スキーム、経路、ポート、前後の空白を含む値と、
`APPLICATION_HOST=` と書いた空欄では、web も worker も起動しない。
不正な値のまま稼働確認だけが通る構成は作れない。
稼働確認も同じ値を `Host` ヘッダーへ付けるためである。

形式が正しくても、利用者が接続するホスト名と違えば正規の要求は 403 になる。
値を変えたら、web を再起動する。

`localhost`、ループバックの IP、`0.0.0.0` のままでも起動する。
ただし通知メールの URL としては使えないため、`bin/diagnose` が注意として知らせる。
公開前に必ず確認する。

```bash
docker compose -f compose.production.yaml up -d --force-recreate web
```

稼働確認をループバックの IP へ直接送る場合は、`Host` を明示する。
付けないと、正しく動いていても 403 になる。

```bash
curl -fsS -H "Host: officeweave.example.com" http://127.0.0.1:3210/up
```

### 公開するポート

利用者が 80 または 443 以外のポートへ接続する場合は、
`APPLICATION_PORT` へその公開ポートを設定する。
逆プロキシの有無とは関係しない。

```text
WEB_PORT          ホストから web コンテナへ公開する
APPLICATION_PORT  利用者が接続する公開ポート
```

直接公開して両者が同じになる場合もあれば、
逆プロキシが変換して異なる場合もある。

```text
逆プロキシが 443 を公開する:
  WEB_PORT=3210 / APPLICATION_PORT は未設定
逆プロキシが 8443 を公開する:
  WEB_PORT=3210 / APPLICATION_PORT=8443
逆プロキシを使わず 3210 を直接公開する:
  WEB_PORT=3210 / APPLICATION_PORT=3210
```

`APPLICATION_PORT` を設定しないと、通知メールの URL からポートが落ち、
利用者は画面へ戻れない。逆に、利用者が 443 へ接続する構成で設定すると、
内部のポートがメール本文の URL へ入る。

設定後は `bin/diagnose` の「メール本文の URL」で、
利用者が接続する形になっているかを確認する。

### 署名に使う鍵

```bash
docker compose -f compose.production.yaml run --rm web bin/rails secret
```

出力された値を `.env` の `SECRET_KEY_BASE` へ設定する。
この値が変わると、進行中のセッションはすべて無効になる。

## 4. 起動

運用環境では配布用の構成を使う。

```bash
docker compose -f compose.production.yaml up -d --build
```

開発や試用では、開発用の構成を使う。

```bash
docker compose up -d --build
```

データベースの作成と移行は起動時に自動で実行される。

### 公開先

既定では loopback にだけ公開する。逆プロキシの背後へ置く構成を前提としている。

```text
http://127.0.0.1:3210
```

逆プロキシを使わず、外部から直接接続させる場合に限り `.env` へ次を設定する。

```text
WEB_BIND_ADDRESS=0.0.0.0
```

暗号化された通信を終端する仕組みは、このリポジトリに含まれていない。
`WEB_BIND_ADDRESS=0.0.0.0` のまま公開ネットワークへ置かない。

### 起動するサービス

```text
db      PostgreSQL。業務データと未処理のジョブを別のデータベースへ保持する
web     画面と API
worker  メールと Webhook の送信。ホストへポートを公開しない
```

`docker compose -f compose.production.yaml up -d` で 3 つとも起動する。
worker は web の稼働を待って起動する。データベースの準備は web が行うためである。

worker が止まっていると、送信は行われずジョブが溜まる。データは失われない。

```bash
docker compose -f compose.production.yaml ps
```

```bash
docker compose -f compose.production.yaml logs -f worker
```

```bash
docker compose -f compose.production.yaml exec -T web bin/jobs_status
```

### 2 つの構成の違い

| 項目          | 開発用（`compose.yaml`）  | 配布用（`compose.production.yaml`） |
| ----------- | -------------------- | ----------------------------- |
| ソースコード      | ホストから共有              | イメージへ取り込む                     |
| 配信物         | 要求のたびに解決             | 事前に組み立て済み                     |
| 実行利用者       | 管理者                  | 専用の利用者                        |
| 依存          | 開発と検証の分も含む           | 実行に必要な分のみ                     |
| 暗号化された通信    | 必須にしない               | 既定で必須（`FORCE_SSL` で切り替え）      |
| project 名     | `officeweave_development` | `officeweave_production`   |
| データボリューム     | `development_db_data`     | `production_db_data` `production_storage_data` |
| ジョブ用データベース   | `officeweave_development_queue` | `officeweave_production_queue` |

## 5. 最初の利用者の作成

```bash
docker compose -f compose.production.yaml exec web bin/rails db:seed
```

`.env` に設定した値で、最初の管理者が作られる。
既に利用者が存在する場合は何も行わない。

`INITIAL_USER_EMAIL` と `INITIAL_USER_PASSWORD` のどちらかが未設定の場合、
利用者は作成されず、必要な設定を知らせて終わる。推測した資格情報では作らない。

作成後は `INITIAL_USER_PASSWORD` を `.env` から削除してよい。

## 6. 確認

```bash
docker compose -f compose.production.yaml exec web bin/diagnose
```

失敗が 0 件であることを確認する。
「注意」が残る場合は、内容を読んで対処するか、意図した状態であることを確かめる。

```bash
curl -s http://127.0.0.1:3210/health
```

`{"status":"ok",...}` が返れば、依存先まで含めて動作している。

画面へログインし、最初の管理者で操作できることを確認する。

## 7. 動作の確認（任意）

一通りの機能を試す場合は、確認用のデータを投入できる。

```bash
docker compose -f compose.production.yaml exec web bin/rails officeweave:demo_data
```

実運用を始める前に、投入した組織ごと削除する。

## 8. 運用環境での追加の作業

### 到達経路

このリポジトリには、暗号化された通信を終端する仕組みを含めていない。
組織の環境にある逆プロキシの背後へ置き、そこで終端する。

公開先は `WEB_BIND_ADDRESS` と `WEB_PORT` で変更できる。
既定は `127.0.0.1:3210` である。

### バックアップ

```bash
script/production_backup
```

書庫はホストの `backups/` へ作られる。取得のあいだ `web` は停止し、画面は使えない。

復元は次による。

```bash
script/production_restore backups/<書庫>
```

詳しくは [バックアップと復元](backup.md) を参照する。
取得しているだけでは復元できることの確認にならない。復元まで一度試す。

### 送信の状況

メールと Webhook はやり直しを含めて最大 5 回まで実行する。
実行は at-least-once であり、同じ通知が二度届くことがある。

やり直しを尽くした失敗は消さずに残る。定期的に確認する。

```bash
docker compose -f compose.production.yaml exec -T web bin/jobs_status --failed
```

詳しくは [設定](../development/configuration.md) を参照する。

### Webhook の送信先

Webhook は既定で、組織の外にある http / https の宛先だけへ送信する。
ポートは 80 番または 443 番に限る。https を推奨する。

ループバックや私用アドレスへは送信しない。保存時と送信時の両方で検査する。

閉じたネットワーク内の宛先へ送る必要がある場合だけ、`.env` へ次を設定する。
防御を弱める設定であるため、必要な origin だけを挙げる。

```text
WEBHOOK_PRIVATE_DESTINATION_ALLOWLIST=http://hooks.internal.example
```

設定したら診断で確認する。

```bash
docker compose -f compose.production.yaml exec web bin/diagnose
```

詳しくは [設定](../development/configuration.md) を参照する。

### 更新

[アップグレード](upgrade.md) の手順に従う。

## 9. 停止と削除

```bash
docker compose -f compose.production.yaml down
```

データも含めて削除する場合は次を実行する。

```bash
docker compose -f compose.production.yaml down -v
```

この操作は、データベースの内容とアップロードされたファイルを削除する。取り消せない。
実行前にバックアップを取得し、削除してよい環境であることを確認する。
