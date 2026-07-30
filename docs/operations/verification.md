# OfficeWeave 総合検証

本書は、公開する前に一度通す確認の手順を定義する。

個々の機能は自動の検証で確かめている。
ここで確かめるのは、それらを組み合わせたときに前提が崩れないことである。

## 1. 手元の検証（開発用の構成）

```bash
docker compose exec web bin/verify
```

書式、依存の脆弱性、静的解析、テスト（システムテストを含む）、初期データの投入。

コンテナ内では Docker を扱えないため、構成そのものの検査は分けてある。
ホスト側で実行する。

```bash
script/check_compose_isolation
```

開発用と配布用の project 名、データボリューム、公開ポートが分かれていることを確かめる。

## 2. クリーンな環境からの起動（開発用の構成）

蓄積した状態ではなく、何も無い状態から起動できることを確かめる。
本節は開発用の構成に対して実行する。`-f compose.production.yaml` は付けない。

```bash
docker compose down -v
```

```bash
docker compose up -d --build
```

```bash
curl -s http://127.0.0.1:3210/health
```

```bash
docker compose exec web bin/rails db:seed
```

```bash
docker compose exec web bin/diagnose
```

## 3. 配布用の構成

開発用で通ることと、配布したものが動くことは別である。

```bash
docker compose -f compose.production.yaml up -d --build
```

```bash
docker compose -f compose.production.yaml exec web bin/diagnose
```

開発用と配布用を同じホストで同時に起動する場合は、
どちらかの `WEB_PORT` を変更する。公開ポートだけは共有できない。

```bash
WEB_PORT=3211 docker compose -f compose.production.yaml up -d
```

データの分離は、実際に消して確かめる。

```text
1. 開発用と配布用のそれぞれへ、区別できる記録を入れる
2. 開発用で down -v を実行する
3. 配布用の記録が残っていることを確かめる
4. 逆向きでも同じことを確かめる
```

イメージへ鍵と接続情報が含まれていないことも確かめる。

```bash
docker run --rm --entrypoint sh <イメージ名> -c 'ls config/master.key .env'
```

いずれも存在しないことが正しい。

## 4. バックアップからの復元

取得できているだけでは、復元できることの確認にならない。

```text
1. 記録の件数を数え、storage へ確認用のファイルを置く
2. script/production_backup を実行する
3. ホストの backups/ へ書庫ができていることを確かめる
4. web を再作成し、書庫が残っていることを確かめる
5. 記録を削除し、storage へ書庫にないファイルを追加する
6. FORCE=1 script/production_restore <書庫> を実行する
7. 件数が取得前と一致することを確かめる
8. 添付ファイルの内容が読めることを確かめる
9. 取得後に追加したファイルが残っていないことを確かめる
```

欠けた書庫で復元を試み、既存のデータが変更されないことも確かめる。

## 5. Webhook の送信先

外部の宛先へ実際に送るのではなく、拒否と許可の境界を確かめる。

```text
1. 送信先へ http://127.0.0.1/ を登録しようとして、拒否されることを確かめる
2. 送信先へ http://example.com:8080/ を登録しようとして、拒否されることを確かめる
3. WEBHOOK_PRIVATE_DESTINATION_ALLOWLIST を空のまま bin/diagnose を実行し、
   「設定なし」と出ることを確かめる
4. 書式の不正な値を設定して bin/diagnose を実行し、失敗することを確かめる
```

実在する外部の宛先や、クラウドのメタデータサービスへは送信しない。
送信そのものの確認は、`test/jobs/deliver_webhook_job_test.rb` が
プロセス内の受信サーバーで行っている。

## 6. 主要な業務の流れ

`test/system/end_to_end_test.rb` が、次を画面の操作だけで通す。

```text
部門の作成と所属の追加
公開範囲を指定したお知らせと、範囲外からは見えないこと
予定の登録と、それに結びつく予約
同じ時間帯の予約が拒否されること
申請の提出、担当分としての把握、承認
文書の公開と、日本語の語句での検索
```

自動で実行されるため、手作業での確認は不要とする。

## 7. 自動実行

`.github/workflows/verify.yml` が、変更のたびに次を実行する。

```text
Compose 構成の分離の検査
bin/verify（開発用の構成）
配布用の構成での起動、稼働確認、診断
配布用の構成でのバックアップと復元
```

自動実行では、同じホストで複数の検証が並行しうる。
衝突を避けるため、実行ごとに一意な project 名を `-p` で指定する。
