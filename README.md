# OfficeWeave

組織の情報共有と日常の手続きを、ひとつの基盤で完結させるための組織向けコラボレーション基盤です。

## 現在の状態

```text
0.1.0
```

組織の日常業務を一巡できる範囲を実装した段階です。
互換性はまだ保証しません。変更の内容は [変更履歴](CHANGELOG.md) を参照してください。

## 起動

必要なものは Docker と Docker Compose だけです。
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

パスワードは 15 文字以上にします。大文字・数字・記号の混在は不要です。
`change_me`、`password`、`officeweave` は、表記を変えても使用できません。

```bash
docker compose up -d --build
```

初回のみ、最初の利用者を作成します。

```bash
docker compose exec web bin/rails db:seed
```

作成後、`INITIAL_USER_PASSWORD` は `.env` から削除できます。

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

設定を変更する場合は `.env` を編集します。設定可能な項目は [設定](docs/development/configuration.md) を参照してください。

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

配布用の構成でバックアップを取得します。書庫はホストの `backups/` へ作られます。

```bash
script/production_backup
```

```bash
script/production_restore backups/<書庫>
```

```bash
docker compose exec web bin/setup --skip-server
```

ホストのデータベースクライアントから直接つなぐ場合は、追加の構成を重ねます。
通常の起動では、データベースはホストへ公開しません。

```bash
docker compose -f compose.yaml -f compose.database.yaml up -d
```

接続先は `127.0.0.1:55432` です。`.env` の `DATABASE_PUBLISHED_PORT` で変更できます。

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

## 目指す価値

- 組織、部門、所属、権限をひとつの基盤で定義し、各機能がそれを共有する
- お知らせ、予定、設備・備品の予約、申請と承認、文書へ、同じ入口から到達できる
- 手続きの状態と履歴が記録として残り、後から追跡できる
- 導入と運用にかけられる手間が限られている組織でも運用できる

## 提供形態

最初の提供形態はセルフホストです。

- 利用者が自組織の環境へ導入し、運用できることを最優先の要件とします
- 外部サービスへの接続を、基本機能の動作条件にしません
- 現段階では、常設の公開サービスを提供しません

運用込みでの提供は、実際に要望が確認された場合に限り検討します。

## 対応言語

利用者向け画面は、最初から次の 2 言語に対応します。

- 日本語 (`ja`)
- 英語 (`en`)

初期の既定言語は日本語です。
ブラウザーの言語設定を反映し、画面上で切り替えることもできます。

## ドキュメント

- [製品ビジョン](docs/product/vision.md) — 解決したい問題、初期範囲、非目標
- [アーキテクチャ原則](docs/architecture/principles.md) — 設計契約と依存方針
- [開発規約](docs/development/conventions.md) — 命名、言語、多言語化の取り決め
- [ロードマップ](docs/roadmap.md) — Phase 一覧と進行規則
- [実行キュー](docs/execution_queue.md) — タスク分解と現在地
- [技術構成](docs/development/tech_stack.md) — 採用技術、版数、更新方針
- [設定](docs/development/configuration.md) — 環境変数と稼働確認
- [テスト方針](docs/development/testing.md) — テストの層と実行方法
- [認証方式の差し替え](docs/development/authentication.md) — 外部認証への差し替え手順
- [品質基盤](docs/development/quality.md) — 書式検査と各種検査の実行方法
- [アクセシビリティ方針](docs/development/accessibility.md) — 画面が満たすべき最低要件
- [導入手順](docs/operations/installation.md) — 自組織の環境への導入
- [運用](docs/operations/operations.md) — 日常的な運用と監視
- [バックアップと復元](docs/operations/backup.md) — 取得と復元の手順
- [アップグレード](docs/operations/upgrade.md) — 入れ替えの手順と診断
- [総合検証](docs/operations/verification.md) — 公開前に通す確認
- [リリース手順](docs/operations/release.md) — 版数の付け方と公開の手順
- [変更履歴](CHANGELOG.md) — 版ごとの変更点
- [脆弱性の報告](SECURITY.md) — 報告の方法と対応の流れ
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

現在の実行順と完了状況は [実行キュー](docs/execution_queue.md) を参照してください。
重大な不具合を解消する安定化期間中であり、公開リリースはまだ提供していません。

README にはタスク番号を複製しません。現在地の正本は実行キューだけです。
