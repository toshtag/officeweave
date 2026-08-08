# 監視

動いているかを確かめる方法と、記録の読み方をまとめます。
症状から調べる場合は [困ったとき](troubleshooting.md) を参照してください。

## 稼働の確認

| 経路        | 用途                    | 期待する応答                |
| --------- | --------------------- | --------------------- |
| `/up`     | コンテナの再起動判定            | 200                   |
| `/health` | 監視と通報                 | 200、依存先に問題があれば 503    |

`/health` が確かめるのは次の 3 つである。どれかが失敗すると 503 になる。

```text
database  業務データへ問い合わせられるか
queue     ジョブの保存先へ問い合わせられるか。積めないと送信を受け付けられない
storage   添付ファイルの保存先へ書けるか
```

`worker` が動いているかは `/health` では見ない。画面の応答とは別の問題であり、
再起動や切り離しの判断へ混ぜない。worker の不在は `bin/diagnose` と
稼働の通知で扱う。

保存領域は権限だけを見る。実際に書いて確かめる形にすると、監視の間隔が
そのまま書き込みの回数になる。書き込みまでの確認は `bin/diagnose` が行う。

保存先のディレクトリは、最初の保存で作られる。まだ無い場合は、存在する
一番近い親が書けるかを見る。作って確かめる形にはしない。稼働確認が
構成を変えることになる。経路の途中がファイルであれば、作れないため失敗とする。

再起動判定に `/health` を使わない。
データベースの一時的な不調で、アプリケーションが再起動を繰り返す。

どちらの経路も `Host` の検査を受ける。
ループバックの IP へ直接確かめるときは、`Host` ヘッダーを明示する。

```bash
docker compose -f compose.production.yaml exec web \
  sh -c 'curl -fsS -H "Host: ${APPLICATION_HOST}" http://127.0.0.1:3000/up'
```

## 記録

```bash
docker compose -f compose.production.yaml logs -f web
```

```bash
docker compose -f compose.production.yaml logs -f db
```

```bash
docker compose -f compose.production.yaml logs -f worker
```

記録の保管と回収は、組織の環境にある仕組みへ委ねている。

### 構造化した記録

`LOG_FORMAT=json` を指定すると、記録を 1 行 1 件の JSON で出す
（[設定](configuration.md#記録)）。

```json
{"time":"2026-08-03T02:30:00.123Z","level":"INFO","event":"http_request","method":"GET","path":"/documents","status":200,"controller":"DocumentsController","action":"index","duration_ms":12.3,"user_id":1,"organization_id":1,"request_id":"a1b2c3"}
```

要求 1 件、送信 1 件を、それぞれ 1 行の要約として出す。

```text
event=http_request   method path status controller action duration_ms user_id organization_id
event=job_performed  job job_id queue attempt duration_ms
```

```text
- 経路に問い合わせ文字列は含めない。絞り込みの値が記録へ残らないようにする
- 例外は種類だけを残す。文面には利用者が入力した値が入り得る
- 利用者と組織は識別子だけを残す。名前とメールアドレスは残さない
- 要求の識別子は request_id の項目として出す。文の接頭辞にはしない
- 改行を含む記録も 1 行に収める
- 行形式では、この要約を出さない。Rails が出す行と二重になる
```

書き出し先は変わらない。運用環境では標準出力へ出る。
値を変更したら web と worker を再起動する。

## 送信の状況

メールと Webhook は worker が送る。溜まっていないか、失敗が残っていないかを確認する。

```bash
docker compose -f compose.production.yaml exec -T web bin/jobs_status
```

```bash
docker compose -f compose.production.yaml exec -T web bin/jobs_status --failed
```

worker が止まっていると、送信は行われずジョブが溜まる。データは失われない。
`bin/diagnose` は worker の不在を失敗として報告する。

Webhook の配送は at-least-once とする。相手が受理した直後に接続が切れた
場合、同じ本文が二度届くことがある。届いたことを確かめる手段がないため、
届かないより届きすぎる側へ倒している。

受け取る側は、本文の `event` と `occurrence` の組で二度届いた分を捨てる。
本文には形の版（`version`）も入っており、対応している形かどうかを本文だけで
判断できる。

送信の記録は試行ごとに増える。残す日数は
[設定](configuration.md#記録の保持) で指定する。

## 稼働の通知

`OPERATIONS_EMAIL` を指定すると、稼働の異常を 1 日 1 回知らせる
（[設定](configuration.md#稼働の通知)）。

```text
OPERATIONS_EMAIL=ops@example.com
```

```text
- 宛先は業務の管理者ではなく、環境を預かる運用者とする
- 送るのは異常があるときだけとする。無事は知らせない
- 知らせるのは、診断の失敗と、放っておくと運用が成り立たなくなる注意だけ
- 設定として選んだ結果の注意（内部宛先の許可など）は送らない
```

届く文面は次の形である。

```text
件名: 稼働に 2 件の異常があります

次の 2 件を確認してください。

- [注意] 失敗したジョブ
  2 件あります。bin/jobs_status --failed で内容を確認してください。
- [失敗] データベースの移行
  未適用の移行があります。
```

異常が無い日は何も届かない。届かないことを、異常が無いことの知らせとする。

同じ異常が続いているあいだも届かない。毎日同じ内容が届くと、通知そのものが
読まれなくなる。7 日を過ぎると改めて届く。読み流したまま忘れられると、
知らせない期間がそのまま放置の期間になる。

異常の組み合わせが変われば、7 日を待たずに届く。直った場合と、別の異常が
増えた場合の両方が対象である。

知らせた記録は残る。届いていないと思ったときに、送ったかどうかを確かめられる。

メールの送信を設定していない場合は届かない。送信の設定は
[設定](configuration.md) を参照。
`bin/diagnose` の「メールの送信」で、送る先があるかを確認できる。
