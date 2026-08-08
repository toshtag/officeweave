# 貢献について

不具合の報告、機能の提案、修正の提出を歓迎します。

## 開発環境

必要なものは Docker Engine と Docker Compose だけです。
Ruby と PostgreSQL をホストへ導入する必要はありません。

```bash
cp .env.example .env
```

```bash
docker compose up -d --build
```

`http://127.0.0.1:3210` が開けば準備できています。

## 変更したら

一括検証を実行してください。書式、依存の脆弱性、静的解析、テストが走ります。

```bash
docker compose exec web bin/verify
```

継続的インテグレーションも同じ検証を呼びます。ただし自動実行では、これに
加えて構成と配布物に関する検査も走ります。手元では実行できないものが
あるためです。

範囲を絞って実行することもできます。

```bash
docker compose exec web bin/verify checks
```

```bash
docker compose exec web bin/verify tests
```

実際のブラウザーを使うテストは別に用意してあります。

```bash
docker compose -f compose.yaml -f compose.browser.yaml exec web bin/rails test:browser
```

## 開発環境を作り直す

開発用のデータベースの内容は失われます。取り消せません。配布用の構成は
対象になりません。

```bash
script/reset_development
```

## お願いしたいこと

- 不具合の修正には、できれば回帰テストを添えてください。修正を外すと落ちる
  ものであれば十分です
- 大きな変更や、画面と権限にまたがる変更は、先に Issue で相談してください。
  作りかけの実装を捨てることになる前に、方針を合わせられます
- 利用者へ見える文字列は、日本語と英語の両方を用意してください
  （[多言語化の取り決め](docs/development/conventions.md)）

コミットメッセージ、ブランチ名、PR の書式は問いません。

## 迷ったら

| 知りたいこと           | 参照                                                    |
| ---------------- | ----------------------------------------------------- |
| 設計の契約と依存の方針      | [アーキテクチャ原則](docs/development/architecture.md)          |
| 命名と多言語化の取り決め     | [開発規約](docs/development/conventions.md)                |
| テストの層と実行方法       | [テスト方針](docs/development/testing.md)                   |
| 画面が満たすべき最低要件     | [アクセシビリティ方針](docs/development/accessibility.md)        |

このリポジトリの既存のコメントとテスト名は日本語です。合わせていただけると
読み手が揃いますが、必須ではありません。

## 脆弱性を見つけた場合

Issue ではなく [SECURITY.md](SECURITY.md) の手順で連絡してください。
