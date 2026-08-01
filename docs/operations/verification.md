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
script/seed_initial_user
```

`.env` へ `INITIAL_USER_EMAIL` と `INITIAL_USER_PASSWORD` を設定していない場合、
利用者は作成されず、必要な設定を知らせて終わる。既定の資格情報は用意しない。

資格情報は一時コンテナにだけ渡る。稼働中の web と worker には渡らない。

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

## 10. CSV 出力の安全性

確かめるのは次の 2 つである。書き出した CSV の各データセルが、数式として
解釈され得る開始文字を持たない構造になっていること。OfficeWeave 内での
書き出しと再取り込みが、元の値を保つこと。

```text
1. = + - @ で始まる値が、先頭に ' を付けて書き出される
2. タブ、復帰、改行で始まる値も同じく保護される
3. 全角の ＝ ＋ － ＠ で始まる値も同じく保護される
4. カンマ、引用符、改行を含む値が 1 つのセルに留まり、行と列が増えない
5. 利用者 CSV を書き出して取り込むと、元のデータと一致する
6. 元から ' で始まる値も一致する
7. 利用者 CSV と部門 CSV が同じ生成経路を使う
```

個別の表計算ソフトが実際にどう表示し評価するかは、確認の対象にしない。
製品、版、取り込み設定によって異なるためである。保証できるのは上の構造と
往復までであり、開いた先での安全までは請け合わない。

保護と復元は `app/models/csv_transfer.rb` の 1 か所に置き、利用者 CSV の
書き出しと取り込み、部門 CSV の書き出しがここを通る。標準の CSV を
`CsvTransfer` の外から参照していないことも、同じ検証で押さえている。

開始文字ごとの保護と往復は `test/models/csv_transfer_test.rb` が、
書き出しと取り込みを通した往復は `test/models/user_csv_test.rb` が、
部門 CSV の書き出しは `test/models/department_csv_test.rb` が、
画面からの書き出しは `test/controllers/data_transfers_controller_test.rb` が
押さえている。ここで確かめるのは、実際に動いている構成でも同じである
ことである。

## 11. 管理者不在の防止

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

## 12. 認証方式の解決

設定した認証方式が、そのまま稼働中の構成になることを確かめる。

```text
1. 未設定で起動し、bin/diagnose の「認証方式」が internal になる
2. AUTHENTICATION_PROVIDER=internal で起動し、同じ結果になる
3. 未登録の名前を指定すると起動しない
4. 空文字を指定すると起動しない
5. 起動しない場合の出力に、環境変数名と指定した値と利用可能な方式がある
6. 未登録の名前でも空文字でも、内部認証へ切り替わらない
7. web と worker へ同じ値が渡る
8. 別の実装が internal を名乗ると、起動前に失敗する
9. 衝突しても、元の internal の登録が維持される
10. 同じ実装の登録を繰り返しても失敗しない
```

`.env` は書き換えず、コマンド単位で値を与える。

```bash
AUTHENTICATION_PROVIDER=does-not-exist docker compose run --rm web bin/rails runner 'puts "BOOTED"'
```

`BOOTED` が出力されず、終了状態が 0 以外になることが正しい。

web と worker への伝播は `script/check_compose_isolation` が、
解決そのものは `test/models/authentication/provider_registry_test.rb` と
`test/models/authentication/provider_boot_test.rb` が押さえている。
ここで確かめるのは、実際に動いている構成でも同じであることである。

## 13. セッションの期限と受け入れる Host

設定ファイルの記述ではなく、起動した配布用の構成への要求で確かめる。

```text
1. 正しい Host で /up が 200
2. 正しい Host で /health が 200
3. 想定外の Host で /up が 403
4. 想定外の Host で /health が 403
5. 想定外の Host で保護された画面が 403
6. Host ヘッダーを省いたループバックへの要求が 403
7. compose の healthcheck が healthy になる
8. ログイン応答の session_id に有限の有効期限が付く
9. その有効期限が、記録側の expires_at と一致する
10. APPLICATION_HOST= と空欄にすると起動しない
11. スキームやポートを含む値では起動しない
12. IP アドレスとして成立しない値では起動しない
13. APPLICATION_PORT を設定するとメールの URL にポートが入る
14. WEB_PORT だけを変えてもメールの URL にポートが混ざらない
```

`docker compose config` で、空欄が `localhost` へ置き換わらないことも確かめる。
置き換わると、誤設定のまま起動してしまう。

`.env` は書き換えず、専用の project 名と一時的な env ファイルで起動する。

```bash
curl -s -o /dev/null -w '%{http_code}\n' \
  -H 'Host: unexpected.example' http://127.0.0.1:3210/up
```

`403` が返ることが正しい。

期限そのもの（無操作 30 分、絶対 8 時間、境界の時刻、活動で絶対期限が
延びないこと、定期削除が期限切れだけを消すこと）は
`test/models/session_test.rb` と `test/controllers/sessions_controller_test.rb`
が押さえている。ここで確かめるのは、実際に動いている構成でも同じであることである。

## 14. 主要な業務の流れ

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

## 15. 申請の状態遷移の直列化

同じ申請へ競合する操作が同時に届いても、成立するのが 1 件だけであることを
確かめる。二つの画面から同じ承認待ちの申請を開き、同時に送信する。

```text
1. 承認と差し戻しを同時に送っても、成立するのは片方だけ
2. 決裁の履歴は 1 件だけ残り、敗れた側の理由は残らない
3. 申請者への通知は、最終の状態に対応する 1 種類だけになる
4. 敗れた側には、現在の状態では処理できない旨が示される
5. 同じ下書きを二重に提出しても、成立する提出は 1 件だけ
6. 取り下げと決裁が競合しても、成立する操作は 1 件だけ
7. 取り下げが先に成立した場合は、決裁の通知も送信も作らない
8. 決裁を任されていない利用者は、これまでどおり拒まれる
```

遷移の可否は `app/models/request.rb` の `change_status` が、申請の行を
占有して読み直した状態だけで決める。提出、決裁、取り下げはいずれもここを
通る。要求を受け入れる側は立場だけを確かめ、状態の判断には関与しない。

同時実行と行ロックは `test/models/request_concurrency_test.rb` が、
成立しなかった場合の画面は `test/controllers/request_decisions_controller_test.rb`
と `test/controllers/request_submissions_controller_test.rb` が押さえている。
自動の並行テストを正本とし、ここで確かめるのは、実際に動いている構成でも
同じであることである。

## 16. パスワードの最低要件と初期資格情報

新しく設定するパスワードが同じ契約を通ることと、既知の初期値のまま
使い始められないことを確かめる。

```text
1. 管理者画面で 14 文字のパスワードを拒否し、理由が画面へ出る
2. 管理者画面で 15 文字のパスワードを受理する
3. 大文字・数字・記号の混在を求めない
4. 空白を含む値は受理し、空白だけの値は長さを満たしていても拒否する
5. change_me、password、officeweave を、表記を変えても拒否する。
   大文字小文字の違い、ASCII 空白、全角空白やノーブレークスペースで前後を
   囲んだ場合も拒否する。内部の空白と部分一致は拒否の理由にしない
6. 既存利用者の氏名や権限の更新では、新しいパスワードを求めない
7. 要件を満たさない INITIAL_USER_PASSWORD では作成が失敗し、利用者を作らない
8. 初期利用者の作成後、web と worker に INITIAL_USER_PASSWORD が残らない
9. seed 用の一時コンテナが残らない
10. 同名のホスト環境変数があっても、.env または --env-file の値で作成される
11. bin/diagnose が、Rails の実行環境へ渡った INITIAL_USER_PASSWORD を知らせる
12. bin/diagnose が、設定に残った既知の初期値を変数名だけで知らせる
13. bin/diagnose が、既知の初期値を使う利用中の管理者を知らせる
```

判定は `app/models/authentication/password_policy.rb` の 1 か所に置き、
管理者画面、`script/seed_initial_user`、CSV 取込による新しい利用者、
`bin/diagnose` のすべてがここを通る。

初期利用者の資格情報は、稼働し続ける web と worker へは渡さない。
`script/seed_initial_user` が作る一時コンテナにだけ渡す。
値の入力元は `.env` または `--env-file` だけとし、同名のホスト環境変数は使わない。
非伝播は `script/check_compose_isolation` が、スクリプトの契約は
`test/models/seed_initial_user_script_test.rb` が押さえている。

最低要件は `test/models/authentication/password_policy_test.rb` と
`test/models/user_test.rb` が、画面での拒否は
`test/controllers/users_controller_test.rb` と `test/system/users_test.rb` が、
診断は `test/models/diagnostics_test.rb` が、設定の伝播は
`script/check_compose_isolation` が押さえている。
ここで確かめるのは、実際に動いている構成でも同じであることである。

`bin/diagnose` が見つけられるのは次の 3 つだけである。

```text
Rails の実行環境へ渡った INITIAL_USER_PASSWORD
Rails の実行環境に残った既知の初期値
保存済みの管理者が既知の初期値そのものを使っている状態
```

見えるのは Rails が動いている process の環境だけである。ホストの `.env` に
値が残っているかどうかは分からない。そこはファイルを見て確かめる。
保存済みの digest からは長さも中身も復元できないため、
弱いパスワード全般も判定できない。

## 17. 利用者の無効化と token の失効

無効にした利用者の外部からの接続が残っていないことを確かめる。

```text
1. token を発行した利用者を無効にすると、その token では API を取得できない
2. 無効化のあとで再び有効にしても、無効化前の token では取得できない
3. 再び有効にした利用者は、新しい token を発行して取得できる
4. 無効な利用者には token を発行できない
5. 最後の管理者の無効化が拒否された場合、その管理者の token は失効しない
6. 利用者の一覧に、無効化の影響が日本語と英語で表示される
7. 管理者の無効化と token の発行が同時に走っても、どちらも中断されない
```

失効は `app/models/user.rb` の無効化と同じトランザクションで確定する。
発行は `app/models/api_token.rb` が組織と利用者の行を占有してから行うため、
無効化と同時に実行しても、無効な利用者に有効な token は残らない。

行の取得順序は、無効化と発行で揃える。

```text
組織 KEY SHARE → 利用者 FOR UPDATE
```

api_tokens の INSERT は organization_id の外部キー検査で組織の行を
KEY SHARE で参照する。明示せずに利用者を先に取ると、最後の管理者を守る
更新（組織 → 利用者）と逆順になり、管理者の無効化と発行が同時に走った
ときに `ActiveRecord::Deadlocked` でどちらかが中断される。
組織へ FOR UPDATE を使わないのは、同じ組織の発行同士まで直列にしないためである。

失効と巻き戻しは `test/models/user_test.rb` が、発行の拒否と再発行は
`test/models/api_token_test.rb` が、同時実行と行ロックは
`test/models/api_token_concurrency_test.rb` が、API の境界は
`test/controllers/api/v1/api_access_test.rb` が押さえている。
ここで確かめるのは、実際に動いている構成でも同じであることである。

## 18. 自動実行

`.github/workflows/verify.yml` が、変更のたびに次を実行する。

```text
Compose 構成の分離の検査
bin/verify（開発用の構成）
配布用の構成での起動、稼働確認、診断
配布用の構成での想定外の Host の拒否
配布用の構成でのバックアップと復元
配布用の構成での永続キューと worker
```

自動実行では、同じホストで複数の検証が並行しうる。
衝突を避けるため、実行ごとに一意な project 名を `-p` で指定する。
