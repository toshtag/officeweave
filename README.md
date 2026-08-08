# OfficeWeave

お知らせ、予定、設備・備品の予約、申請と承認、文書共有を、ひとつの画面から
扱える社内向けポータルです。自分たちのサーバーで動かします。

## できること

- お知らせを配信し、誰が読んだかを追える
- 予定を共有し、会議室や備品を予約できる
- 申請を出し、決められた経路で承認する
- 文書を分類して置き、部門ごとに公開範囲を決める
- 組織、部門、所属、権限をひとつ定義すれば、どの機能もそれに従う
- 手続きの状態と履歴が記録に残り、後から追える

画面は日本語と英語に対応します。既定は日本語で、画面上で切り替えられます。

外部のサービスへ接続しなくても、基本の機能はすべて動きます。

## 動かしてみる

必要なのは Docker Engine と Docker Compose だけです。
Ruby と PostgreSQL をホストへ入れる必要はありません。

```bash
git clone https://github.com/toshtag/officeweave.git
```

```bash
cd officeweave && cp .env.example .env
```

`.env` を開き、最初の管理者の資格情報を設定します。既定値はありません。

```text
INITIAL_USER_EMAIL     最初の管理者のメールアドレス
INITIAL_USER_PASSWORD  15 文字以上のパスワード
```

```bash
docker compose up -d --build
```

初回だけ、最初の管理者を作成します。

```bash
script/seed_initial_user
```

`http://127.0.0.1:3210` を開いてログインします。

作成後、`INITIAL_USER_PASSWORD` は `.env` から削除してください。

試用のデータを入れる場合は、次を実行します。

```bash
docker compose exec web bin/rails officeweave:demo_data
```

停止するときは次のとおりです。

```bash
docker compose down
```

自組織へ本番として導入する手順は [導入と運用](docs/operations/index.md) に
あります。上の手順は開発と試用のためのものです。

## バージョン

現在のバージョンは [VERSION](VERSION) にあります。
変更点は [変更履歴](CHANGELOG.md) にあります。

版どうしの互換性はまだ保証しません。以前の版から入れ替える場合は
[アップグレード](docs/operations/upgrade.md) を参照してください。

## ドキュメント

| 目的            | 参照                                                     |
| ------------- | ------------------------------------------------------ |
| 画面の使い方        | [操作の手引き](docs/usage/index.md)                          |
| 自組織への導入と運用    | [導入と運用](docs/operations/index.md)                       |
| 修正を送りたい       | [貢献について](CONTRIBUTING.md)                               |
| 脆弱性を見つけた      | [SECURITY.md](SECURITY.md)                             |
| 何を作ろうとしているのか  | [製品ビジョン](docs/vision.md)                                |

いずれの文書も日本語を正本とします。

## ライセンス

```text
GNU Affero General Public License version 3 or later
Copyright (C) 2026 OfficeWeave contributors
```

全文は [LICENSE](LICENSE) を参照してください。
自組織での導入、運用、改変に制限はありません。
改変版を第三者へ提供する場合は、対応するソースコードの提供が必要です。
