# OfficeWeave

組織の情報共有と日常の手続きを、ひとつの基盤で完結させるための組織向けコラボレーション基盤です。

## 現在の状態

```text
pre-alpha
```

アプリケーションの基盤ができた段階です。業務機能はこれから実装します。

## 起動

必要なものは Docker と Docker Compose だけです。
Ruby と PostgreSQL をホストへ導入する必要はありません。

```bash
git clone https://github.com/toshtag/officeweave.git
```

```bash
cd officeweave && cp .env.example .env && docker compose up -d --build
```

初回のみ、最初の利用者を作成します。

```bash
docker compose exec web bin/rails db:seed
```

起動後、`http://localhost:3000` を開きます。
データベースの作成と移行は初回起動時に自動で実行されます。

開発環境の既定の資格情報は `admin@officeweave.test` / `officeweave` です。
`.env` の `INITIAL_USER_EMAIL` と `INITIAL_USER_PASSWORD` で変更できます。
運用環境では必ず変更してください。

設定を変更する場合は `.env` を編集します。設定可能な項目は [設定](docs/development/configuration.md) を参照してください。

稼働確認は次のとおりです。

```bash
curl -s http://localhost:3000/health
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
docker compose exec web bin/setup --skip-server
```

停止と破棄は次のとおりです。`down -v` はデータベースの内容も削除します。

```bash
docker compose down
```

```bash
docker compose down -v
```

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
- [品質基盤](docs/development/quality.md) — 書式検査と各種検査の実行方法
- [アクセシビリティ方針](docs/development/accessibility.md) — 画面が満たすべき最低要件
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

## 現在地と次のタスク

```text
現在の Phase:        P9 Notifications
直近完了 Task:       P8-T4 データベース機能だけで全文検索を実装する
次に実行する Task:   P9-T1 アプリ内通知を実装する
```

進行状況は [実行キュー](docs/execution_queue.md) で管理します。
