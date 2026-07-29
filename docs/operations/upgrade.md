# OfficeWeave アップグレード

本書は、新しい版へ入れ替える手順を定義する。

## 1. 手順

```bash
docker compose exec web bin/backup
```

```bash
git pull
```

```bash
docker compose up -d --build
```

```bash
docker compose exec web bin/diagnose
```

データベースの移行は起動時に自動で実行される。

### 手順の意図

- 先にバックアップを取得する。戻せない状態で入れ替えない
- 入れ替え後に診断を実行する。起動しただけでは分からない不備を洗い出す

## 2. 診断

```bash
docker compose exec web bin/diagnose
```

確認する内容は次のとおり。

```text
データベースへの接続
データベースの移行が適用済みか
必要な拡張機能が有効か
ファイルの保存先へ書き込めるか
署名に使う鍵が設定されているか
メールの送信設定
メール本文の URL に使うホスト名
有効な管理者が存在するか
```

失敗がある場合は 0 以外で終了する。
自動で実行する場合は、終了状態で判定できる。

「注意」は動作を妨げないが、運用環境では対処が必要な項目を示す。

## 3. 失敗した場合

```bash
docker compose down
```

```bash
git checkout <前の版>
```

```bash
docker compose up -d --build
```

データベースの移行を戻す必要がある場合は、取得しておいたバックアップから復元する。

```bash
docker compose exec -e FORCE=1 web bin/restore <書庫のパス>
```

移行を個別に戻す操作は用意していない。
版のあいだで移行の内容が変わると、戻す操作そのものが失敗しうる。

## 4. 版をまたぐ注意

- 版を飛ばした入れ替えは確認していない。順に上げる
- 入れ替え前のバックアップは、入れ替えが安定するまで保管する
- 設定項目が増えた場合は [.env.example](../../.env.example) との差分を確認する
