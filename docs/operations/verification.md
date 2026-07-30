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
10. 未処理のジョブが取得時点へ戻っていることを確かめる
```

`queue_database.sql` を含まない古い書庫でも復元できること、
その場合に未処理のジョブが失われる旨の警告が出ることも確かめる。

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

## 6. 永続キューと worker

送信そのものは外部へ出さず、保存と再開だけを確かめる。

```text
1. 配布用の構成で db、web、worker の 3 つが起動する
2. worker にホストへの公開ポートがない
3. ジョブ用データベースに solid_queue の表がある
4. worker を止めた状態でジョブを積み、データベースへ残ることを確かめる
5. web を作り直しても同じジョブが残る
6. worker を作り直しても同じジョブが残る
7. db を再起動しても同じジョブが残る
8. worker を起動すると処理され、待機が空になる
9. 失敗したジョブが自動で消えないことを確かめる
10. bin/jobs_status と bin/diagnose で状態が読める
```

外部の SMTP や Webhook 宛先へは接続しない。
ジョブの投入には、存在しない送信先の ID を使う。

## 7. 添付ファイルの取得経路

添付ファイルは、文書の配下の経路からだけ取得できる。
保存基盤が用意する `/rails/active_storage/` の経路は全環境で作らない。
署名付きの ID を知っていることは、参照できる根拠にしない。

経路の一覧を確かめる。開発用と配布用の両方で行う。

```bash
ROUTES="$(docker compose exec -T web bin/rails routes)"
test -z "$(printf '%s\n' "$ROUTES" | grep 'active_storage' || true)"
```

`grep -q` をそのままつなぐと、上流が書き込み中に閉じられて誤った失敗になる。
出力を一度変数へ受けてから判定する。

```text
1. 経路の一覧に active_storage が現れない
2. bin/diagnose の「添付ファイルの取得経路」が OK になる
3. 通常のフォームから添付を追加でき、文書の画面から取得できる
4. 未ログインで添付の URL へ入ると、ログイン画面へ移る
5. 文書を参照できない利用者が添付の URL へ入ると、見つからない扱いになる
6. /rails/active_storage/blobs/proxy/<署名付き ID>/<ファイル名> が見つからない扱いになる
7. 参照できる状態で得た添付の URL が、公開範囲を狭めた後は取得できない
```

経路が存在しないことは `test/models/attachment_routes_test.rb` が、
取得できる範囲は `test/controllers/attachment_delivery_test.rb` が押さえている。
ここで確かめるのは、実際に動いている構成でも同じであることである。

## 8. 文書添付の更新

文書の編集で、添付の追加と選択削除が既存の添付を壊さないことを確かめる。

```text
1. 文書へ添付を追加しても、既存の添付が維持される
2. 文書の更新が失敗した場合、選択削除した添付が維持される
3. 文書の更新が失敗した場合、添付の削除ジョブは投入されない
4. 成功した選択削除は、ジョブ処理後に未参照の Blob と保存実体も削除する
5. 他の添付から参照されている Blob は、参照が残る間は削除されない
```

追加が置き換えにならないこと、失敗した更新が添付を消さないことは、
`test/controllers/document_attachments_test.rb` と
`test/system/document_attachments_test.rb` が押さえている。
ここで確かめるのは、実際に動いている構成でも同じであることである。

## 9. 利用者 CSV の所属更新

利用者 CSV の `departments` 列が、既存の所属を黙って壊さないことを確かめる。

```text
1. 未知の部門コードを含む取り込みは、行番号とコードを表示して拒否される
2. 拒否されたとき、CSV 内の全利用者の属性と所属が変更されていない
3. departments 列を省略すると、既存の所属が維持される
4. departments 列を付けて空欄にすると、所属がすべて解除される
5. 登録済みのコードだけの場合は、指定された所属へ更新される
```

未知のコードの拒否と全体ロールバックは `test/models/user_csv_test.rb` が、
画面での行番号とコードの表示は `test/controllers/data_transfers_controller_test.rb` と
`test/system/data_transfers_test.rb` が押さえている。
ここで確かめるのは、実際に動いている構成でも同じであることである。

## 10. 管理者不在の防止

組織から利用中の管理者がいなくなる経路が残っていないことを確かめる。

```text
1. 最後の利用中の管理者を一般利用者へ変更できない
2. 最後の利用中の管理者を無効化できない
3. CSV 取込でも同じ理由で拒否され、取込全体がロールバックされる
4. 管理者が 2 人以上いる場合は、1 人の降格または無効化が成功する
5. 同時に 2 人を降格しても、利用中の管理者が 1 人残る
6. 別組織の管理者と、無効にした管理者は人数へ数えない
```

判定は `app/models/user.rb` の 1 か所に置き、画面、無効化、CSV 取込の
すべてがここを通る。同時実行は組織の行を占有して直列化する。

不変条件は `test/models/user_test.rb` と `test/models/user_csv_test.rb` が、
画面での拒否は `test/controllers/users_controller_test.rb` と
`test/system/users_test.rb` が、同時実行と行ロックは
`test/models/user_administrator_concurrency_test.rb` が押さえている。
ここで確かめるのは、実際に動いている構成でも同じであることである。

## 11. 主要な業務の流れ

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

## 12. 自動実行

`.github/workflows/verify.yml` が、変更のたびに次を実行する。

```text
Compose 構成の分離の検査
bin/verify（開発用の構成）
配布用の構成での起動、稼働確認、診断
配布用の構成でのバックアップと復元
配布用の構成での永続キューと worker
```

自動実行では、同じホストで複数の検証が並行しうる。
衝突を避けるため、実行ごとに一意な project 名を `-p` で指定する。
