# OfficeWeave

組織の情報共有と日常の手続きを、ひとつの基盤で完結させるための組織向けコラボレーション基盤です。

## 現在の状態

組織の日常業務を一巡できる範囲を実装した段階です。互換性はまだ保証しません。

「実装した」ことと「本番運用に耐える」ことは分けて扱います。
機能ごとの到達度は [機能到達度](docs/product/capability_matrix.md) にあります。
本番準備済みと判定した機能は、現時点でありません。

現在の版は [VERSION](VERSION) にあります。
版ごとの変更点と、入れ替えが必要な理由は [変更履歴](CHANGELOG.md) にあります。
過去の版から入れ替える場合は [アップグレード](docs/operations/upgrade.md) を参照してください。

## 起動

必要なものは Docker Engine 25.0 以降と Docker Compose v2.24 以降だけです。
Ruby と PostgreSQL をホストへ導入する必要はありません。

```bash
git clone https://github.com/toshtag/officeweave.git
```

```bash
cd officeweave && cp .env.example .env
```

`.env` を開き、最初の利用者の資格情報を設定します。
既定値はありません。設定するまで利用者は作成されません。

```text
INITIAL_USER_EMAIL     最初の管理者のメールアドレス
INITIAL_USER_PASSWORD  15 文字以上のパスワード
```

パスワードの要件は [設定](docs/operations/configuration.md) にあります。

```bash
docker compose up -d --build
```

初回のみ、最初の利用者を作成します。

```bash
script/seed_initial_user
```

資格情報は、このとき作られる一時コンテナにだけ渡します。稼働中の web と
worker には渡しません。扱いの詳細は [設定](docs/operations/configuration.md) にあります。

作成後、`INITIAL_USER_PASSWORD` は `.env` から削除してください。
web と worker を作り直す必要はありません。

動作を確かめるためのデータを入れる場合は、次を実行します。

```bash
docker compose exec web bin/rails officeweave:demo_data
```

起動後、`http://127.0.0.1:3210` を開きます。
データベースの作成と移行は初回起動時に自動で実行されます。

起動するのは 3 つです。

```text
db      PostgreSQL。業務データと未処理のジョブを別のデータベースへ保持します
web     画面と API
worker  メールと Webhook の送信。ホストへポートを公開しません
```

worker が止まっていると、送信は行われずジョブが溜まります。データは失われません。

公開先は既定で loopback だけです。同じ端末の他の開発環境と衝突する場合や、
別の端末から接続したい場合は `.env` の `WEB_BIND_ADDRESS` と `WEB_PORT` を変更します。

設定を変更する場合は `.env` を編集します。設定可能な項目は [設定](docs/operations/configuration.md) を参照してください。

稼働確認は次のとおりです。

```bash
curl -s http://127.0.0.1:3210/health
```

### よく使うコマンド

いずれもリポジトリのルートで実行します。

```bash
docker compose logs -f web
```

```bash
docker compose exec web bin/rails console
```

```bash
docker compose exec web bin/rails test:all
```

```bash
docker compose exec web bin/verify
```

```bash
docker compose exec web bin/diagnose
```

送信の状況を確認します。

```bash
docker compose exec web bin/jobs_status
```

```bash
docker compose exec web bin/jobs_status --failed
```

worker の記録を追います。

```bash
docker compose logs -f worker
```

依存とデータベースを整え直します。server は起動しません。
server と worker は `docker compose up` が起動します。

```bash
docker compose exec web bin/setup
```

開発環境のデータベースを作り直します。内容は失われます。取り消せません。
配布用の構成は対象になりません。

```bash
script/reset_development
```

ホストのデータベースクライアントから直接つなぐ手順は
[設定](docs/operations/configuration.md#データベースの公開) にあります。
バックアップの取得と復元は [バックアップと復元](docs/operations/backup.md) にあります。

停止は次のとおりです。

```bash
docker compose down
```

次はデータベースの内容も削除します。取り消せません。
実行前に、開発用の構成に対して実行していることを確認してください。

```bash
docker compose down -v
```

配布用の構成は project 名もデータボリュームも分けてあるため、
この操作で配布用のデータが失われることはありません。
配布用を操作する場合は、必ず `-f compose.production.yaml` を付けます。

`Gemfile` を変更した場合は再ビルドが必要です。

```bash
docker compose up -d --build
```

## この製品について

- 組織、部門、所属、権限をひとつの基盤で定義し、各機能がそれを共有します
- お知らせ、予定、設備・備品の予約、申請と承認、文書へ、同じ入口から到達できます
- 手続きの状態と履歴が記録として残り、後から追跡できます
- 画面は日本語 (`ja`) と英語 (`en`) に対応します。既定は日本語で、画面上で切り替えられます
- セルフホストを提供形態とします。外部サービスへの接続を基本機能の動作条件にしません

解決したい問題、製品範囲、非目標は [製品ビジョン](docs/vision.md) にあります。

## ドキュメント

### 導入して運用する

- [導入手順](docs/operations/installation.md) — 自組織の環境への導入
- [設定](docs/operations/configuration.md) — 環境変数と稼働確認
- [運用管理](docs/operations/administration.md) — 利用者と組織の管理、監視、監査
- [バックアップと復元](docs/operations/backup.md) — 取得と復元の手順
- [アップグレード](docs/operations/upgrade.md) — 入れ替えの手順と診断
- [変更履歴](CHANGELOG.md) — 版ごとの変更点
- [脆弱性の報告](SECURITY.md) — 報告の方法と対応の流れ

### 開発する

- [アーキテクチャ原則](docs/development/architecture.md) — 設計契約と依存方針
- [開発規約](docs/development/conventions.md) — 命名、作業の進め方、多言語化の取り決め
- [技術構成](docs/development/tech_stack.md) — 採用技術、版数、更新方針
- [テスト方針](docs/development/testing.md) — テストの層と実行方法
- [品質基盤](docs/development/quality.md) — 書式検査と各種検査の実行方法
- [アクセシビリティ方針](docs/development/accessibility.md) — 画面が満たすべき最低要件
- [認証方式の差し替え](docs/development/authentication.md) — 外部認証への差し替え手順
- [リリース手順](docs/development/release.md) — 公開前の確認と、版を出す手順

### プロジェクト

- [製品ビジョン](docs/vision.md) — 解決したい問題、製品範囲、非目標
- [製品範囲](docs/product/product_scope.md) — 機能をどの段階へ置くかの決め方
- [受入条件](docs/product/acceptance_criteria.md) — 到達度と本番準備の判定条件
- [機能到達度](docs/product/capability_matrix.md) — 機能ごとの段階と、いまの到達度
- [決定記録](docs/decisions) — 製品の方向を決めた判断とその理由
- [ライセンス方針](docs/licensing.md) — ライセンスの選定理由と名称の利用範囲

いずれも日本語を正本とします。

## ライセンス

```text
GNU Affero General Public License version 3 or later
Copyright (C) 2026 OfficeWeave contributors
```

全文は [LICENSE](LICENSE) を参照してください。
自組織での導入、運用、改変に制限はありません。
改変版を第三者へ提供する場合は、対応するソースコードの提供が必要です。

## 開発状況

現在の範囲の機能は、経路と検証手段までひととおり実装しています。
一方、[受入条件](docs/product/acceptance_criteria.md) を満たしたと判定した機能は
1 件だけで、残りは未達の項目を持ちます。内訳は
[機能到達度](docs/product/capability_matrix.md) にあります。

互換性の保証はまだ行いません。

今後の作業と既知の不具合は [Issues](https://github.com/toshtag/OfficeWeave/issues) で
管理します。実際に何をどう変えたかは PR と `git log` から辿れます。
