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
DATABASE_PASSWORD      推測されない値へ変更する
INITIAL_USER_EMAIL     最初の管理者のメールアドレス
INITIAL_USER_PASSWORD  最初の管理者のパスワード
APPLICATION_HOST       利用者が接続するホスト名
SMTP_ADDRESS           通知をメールで送る場合
SECRET_KEY_BASE        署名に使う鍵
```

設定できる項目の一覧は [設定](../development/configuration.md) にある。

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

## 5. 最初の利用者の作成

```bash
docker compose -f compose.production.yaml exec web bin/rails db:seed
```

`.env` に設定した値で、最初の管理者が作られる。
既に利用者が存在する場合は何も行わない。

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
