# OfficeWeave 導入手順

自組織の環境へ OfficeWeave を導入する手順です。
設定値を調べる場合は [設定](configuration.md)、やりたいことから探す場合は
[導入と運用](index.md) を参照してください。

## 1. 必要なもの

```text
Docker Engine 25.0 以降
Docker Compose v2.24 以降
アプリケーションへ到達できるホスト名（運用環境）
メールを送信できる SMTP サーバー（通知を使う場合）
```

版を示すのは、構成が起動中の確認間隔（`start_interval`）を使うためである。
これより古い環境では、構成の読み取りの時点で止まる。

Ruby と PostgreSQL をホストへ導入する必要はない。すべてコンテナ内で動作する。

推奨する構成は、単一ホストでの運用である。
複数ホストでの構成は確認していない。

## 2. 取得

```bash
git clone https://github.com/toshtag/officeweave.git
```

```bash
cd officeweave
```

### 開発用と配布用の使い分け

本書の手順は、すべて配布用の構成に対して実行する。
そのため、Compose を呼び出すコマンドには必ず `-f compose.production.yaml` を付ける。

```bash
docker compose -f compose.production.yaml <コマンド>
```

付け忘れると、開発用の構成に対して実行される。
両者は project 名もデータボリュームも分けてあるため、
配布用のデータが壊れることはないが、意図した対象へは届かない。

## 3. 設定

```bash
cp .env.example .env
```

`.env` を編集する。運用環境では、少なくとも次を設定する。

```text
DATABASE_PASSWORD      推測されない値を設定する
INITIAL_USER_EMAIL     最初の管理者のメールアドレス
INITIAL_USER_PASSWORD  最初の管理者のパスワード
APPLICATION_HOST       利用者が接続するホスト名
SMTP_ADDRESS           通知をメールで送る場合
SECRET_KEY_BASE        署名に使う鍵
```

`.env.example` の秘密情報は空欄である。空欄のままでは構成を解決できず、起動しない。

設定できる項目の一覧は [設定](configuration.md) にある。

### 最初の管理者の資格情報

初期利用者は `script/seed_initial_user` で作成する。作成する前に設定する。

```text
INITIAL_USER_EMAIL     必須。既定値はない
INITIAL_USER_PASSWORD  必須。既定値はない。15 文字以上とする
```

要件を満たさない値を設定した場合、作成は失敗し、利用者を作らない。
要件は [設定](configuration.md) にある。

実際に設定した値を、コマンドの例や作業記録へ書き写さない。
本書と `.env.example` に載る値は、いずれも使用できない値である。

作成の判定は組織ごとに行う。`ORGANIZATION_CODE` を変えて実行すると、
その組織に利用者がいない限り、その組織の初期管理者が作られる。
同じ組織に対して繰り返し実行しても、利用者は増えない。

```text
ORGANIZATION_CODE      導入単位となる組織。既定は default
ORGANIZATION_NAME      組織を新しく作る場合の表示名。既定は OfficeWeave
```

### 資格情報の寿命

`INITIAL_USER_*` は、稼働し続ける web と worker へは渡さない。
`script/seed_initial_user` が作る一時コンテナにだけ渡し、処理が終わると
そのコンテナは削除される。値の入力元と、そう決めた理由は
[設定](configuration.md) にある。

初期利用者の作成後は、次の順で片付ける。

```text
1. script/seed_initial_user を実行する
2. 利用者が作成されたことを確かめる
3. .env（または指定した env ファイル）から INITIAL_USER_PASSWORD を削除する
4. 削除できたことをホスト側で確かめる
5. bin/diagnose で Rails の実行環境へ渡っていないことを確かめる
```

web と worker を作り直す必要はない。もともと渡していないためである。

`bin/diagnose` が確かめるのは、Rails の実行環境へ `INITIAL_USER_PASSWORD` が
渡っていないことである。ホストの `.env` に値が残っているかどうかは分からない。
アプリケーションからはホストのファイルが見えないため、そこは手順 4 で確かめる。

設定に残った既知の初期値と、その値をそのまま使っている管理者は、別途知らせる。

### 接続するホスト名

公開する前に `APPLICATION_HOST` を必ず設定します。運用環境では、ここに書いた
1 つのホスト名だけを受け入れ、それ以外の `Host` を持つ要求は 403 で拒みます。

```text
正: officeweave.example.com
誤: https://officeweave.example.com/
```

スキーム、経路、ポートは含めません。逆プロキシの背後へ置く場合は、利用者が
接続するホスト名を書きます。逆プロキシが `Host` を書き換える構成では、
転送される値と一致させてください。

`localhost` やループバックの IP のままでも起動しますが、通知メールの URL
としては使えません。`bin/diagnose` が注意として知らせます。

値を変えたら web を再起動します。

```bash
docker compose -f compose.production.yaml up -d --force-recreate web
```

書ける値と、書き間違えたときにどうなるかは
[設定 — ホスト名の制限](configuration.md#ホスト名の制限) にあります。

### 公開するポート

利用者が 80 または 443 以外のポートへ接続する場合は、
`APPLICATION_PORT` へその公開ポートを設定する。逆プロキシの有無とは関係しない。

設定しないと、通知メールの URL からポートが落ち、利用者は画面へ戻れない。
逆に、利用者が 443 へ接続する構成で設定すると、内部のポートが URL へ入る。

`WEB_PORT` との違いと、構成ごとの組み合わせは
[設定](configuration.md#メール送信) にある。

設定後は `bin/diagnose` の「メール本文の URL」で、
利用者が接続する形になっているかを確認する。

### 署名に使う鍵

```bash
docker compose -f compose.production.yaml run --rm web bin/rails secret
```

出力された値を `.env` の `SECRET_KEY_BASE` へ設定する。
この値が変わると、進行中のセッションはすべて無効になる。

## 4. 起動

運用環境では配布用の構成を使う。

```bash
docker compose -f compose.production.yaml up -d --build
```

1 度の実行で終わる。データベースの準備（移行）は `prepare` という一度きりの
実行が受け持ち、`web` と `worker` はその完了を待ってから起動する。準備が
長引いても、待つ側は待ち切る。

まっさらな状態から、db・web・worker がすべて healthy になるまで待つ。
かかる時間は端末とイメージの有無で変わる。版ごとの実測は
[版ごとの検証](../releases/) にある。

開発や試用では、開発用の構成を使う。

```bash
docker compose up -d --build
```

データベースの作成と移行は起動時に自動で実行される。

### 公開先

既定では loopback にだけ公開する。逆プロキシの背後へ置く構成を前提としている。

```text
http://127.0.0.1:3210
```

逆プロキシを使わず、外部から直接接続させる場合に限り `.env` へ次を設定する。

```text
WEB_BIND_ADDRESS=0.0.0.0
```

暗号化された通信を終端する仕組みは、このリポジトリに含まれていない。
`WEB_BIND_ADDRESS=0.0.0.0` のまま公開ネットワークへ置かない。

### 起動するサービス

```text
db      PostgreSQL。業務データと未処理のジョブを別のデータベースへ保持する
web     画面と API
worker  メールと Webhook の送信。ホストへポートを公開しない
```

`docker compose -f compose.production.yaml up -d` で 3 つとも起動する。
worker は web の稼働を待って起動する。データベースの準備は web が行うためである。

worker が止まっていると、送信は行われずジョブが溜まる。データは失われない。

```bash
docker compose -f compose.production.yaml ps
```

```bash
docker compose -f compose.production.yaml logs -f worker
```

```bash
docker compose -f compose.production.yaml exec -T web bin/jobs_status
```

### 2 つの構成の違い

| 項目          | 開発用（`compose.yaml`）  | 配布用（`compose.production.yaml`） |
| ----------- | -------------------- | ----------------------------- |
| ソースコード      | ホストから共有              | イメージへ取り込む                     |
| 配信物         | 要求のたびに解決             | 事前に組み立て済み                     |
| 実行利用者       | 管理者                  | 専用の利用者                        |
| 依存          | 開発と検証の分も含む           | 実行に必要な分のみ                     |
| 暗号化された通信    | 必須にしない               | 既定で必須（`FORCE_SSL` で切り替え）      |

2 つはデータも分かれています。project 名、イメージ、データボリューム、ジョブ用
データベースがそれぞれ別で、片方で `down -v` を実行しても、もう片方のデータは
残ります。

web と worker は 1 つのイメージを共有します。同じコードを同じ依存で動かすため、
分けても中身が同じものが 2 つできるだけです。

## 5. 最初の利用者の作成

```bash
script/seed_initial_user --production
```

`.env` に設定した値で、最初の管理者が作られる。
既に利用者が存在する場合は何も行わない。

資格情報は一時コンテナにだけ渡る。稼働中の web と worker では実行しない。

`INITIAL_USER_EMAIL` と `INITIAL_USER_PASSWORD` のどちらかが未設定の場合、
利用者は作成されず、必要な設定を知らせて終わる。推測した資格情報では作らない。

作成後は `INITIAL_USER_PASSWORD` を `.env` から削除する。
web と worker の作り直しは要らない。

## 6. 確認

```bash
docker compose -f compose.production.yaml exec web bin/diagnose
```

失敗が 0 件であることを確認する。
「注意」が残る場合は、内容を読んで対処するか、意図した状態であることを確かめる。

```bash
curl -s http://127.0.0.1:3210/health
```

`{"status":"ok",...}` が返れば、依存先まで含めて動作している。

画面へログインし、最初の管理者で操作できることを確認する。

## 7. 動作の確認（任意）

一通りの機能を試す場合は、確認用のデータを投入できる。

```bash
docker compose -f compose.production.yaml exec web bin/rails officeweave:demo_data
```

実運用を始める前に、投入した組織ごと削除する。

## 8. 次に確認すること

導入はここまでで完了です。運用に入る前に、次を読んでください。

| やること              | 参照                                               |
| ----------------- | ------------------------------------------------ |
| 利用者が接続できるようにする    | [設定 — ホスト名の制限](configuration.md#ホスト名の制限)         |
| バックアップを設定する       | [バックアップと復元](backup.md)                           |
| 動いているかを確かめる       | [監視](monitoring.md)                              |
| 通知の送信を確かめる        | [監視 — 送信の状況](monitoring.md#送信の状況)                |
| 新しい版へ入れ替える        | [アップグレード](upgrade.md)                            |

やりたいことから探す場合は [導入と運用](index.md) にあります。

## 9. 停止と削除

```bash
docker compose -f compose.production.yaml down
```

データも含めて削除する場合は次を実行する。

```bash
docker compose -f compose.production.yaml down -v
```

この操作は、データベースの内容とアップロードされたファイルを削除する。取り消せない。
実行前にバックアップを取得し、削除してよい環境であることを確認する。
