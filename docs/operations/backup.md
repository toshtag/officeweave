# OfficeWeave バックアップと復元

本書は、データの取得と復元の手順を定義する。

セルフホストでは、バックアップの取得と保管は導入した組織の責任になる。
手順を製品側で用意し、復元まで含めて確認できる状態にする。

取得も復元も、リポジトリのルートで次のスクリプトを実行する。
スクリプトが内部で `-f compose.production.yaml` を指定する。

```bash
script/production_backup
script/production_restore <書庫>
```

## 1. 取得するもの

バックアップにはひとつの書庫へ次をまとめる。

```text
database.sql        業務データ
queue_database.sql  未処理のジョブ
storage/            アップロードされたファイル
metadata.txt        取得日時、対象のデータベース名、スキーマの版、製品の版
```

未処理のジョブも取得する。含めないと、復元した時点で送信待ちのメールと Webhook が失われる。

片方だけを残すと、復元しても添付ファイルが開けない、
あるいは実体はあるのに参照する記録がない状態になる。

`metadata.txt` に接続情報や鍵は書かない。書庫は組織の外へ持ち出されることがある。

## 2. 取得

```bash
script/production_backup
```

既定ではホストの `backups/` へ書き出す。出力先は引数で変更できる。

```bash
script/production_backup /var/backups/officeweave
```

書庫の名前には取得日時が入る。同じ名前の書庫があっても上書きしない。
標準出力へは、作成した書庫の経路だけを出す。

### 書庫がホストに残る理由

書庫をコンテナ内へ書き出さない。コンテナを入れ替えた時点で失われるためである。

ホストのディレクトリをコンテナへマウントする方法も採らない。
コンテナ内の利用者とホストの利用者で UID が食い違うと書き込めず、
書けた場合も所有者がホストの利用者と異なる書庫が残る。

代わりに、一時コンテナが書庫を標準出力へ流し、スクリプトがホスト側で受け取る。

```text
一時コンテナ  bin/backup --stdout
      ↓  標準出力
ホスト        backups/officeweave-<取得日時>.tar.gz.partial
      ↓  書庫として読めることを確認してから改名
ホスト        backups/officeweave-<取得日時>.tar.gz
```

途中で失敗した場合、`.partial` は削除され、正式な書庫は作られない。

### 取得のあいだの停止

取得時点をそろえるため、取得中は `web` と `worker` を停止する。

```text
- 取得のあいだ、利用者は画面を使えず、メールと Webhook も送られない
- db コンテナは停止しない
- 先に web を止める。新しいジョブが積まれない状態にしてから worker を止める
- worker の停止では、実行中のジョブの終了を待つ
- 取得の前から停止していたサービスは起動しない
- 取得に失敗しても、元々動いていたサービスは再開する
- 再開は web から行う。worker は web の稼働を前提に起動する
```

外部から直接データベースへ書き込む仕組みを持ち込んでいる場合は、
その停止を別途行う必要がある。本書の手順は、この製品の `web` だけを止める。

### 暗号化

`BACKUP_PASSPHRASE_FILE` を指定すると、書庫を暗号化して取得する。
指定した場合だけ働き、既定値は持たない。指定しなければ平文のままである。

```bash
BACKUP_PASSPHRASE_FILE=/etc/officeweave/backup-passphrase script/production_backup
```

```text
- 暗号化はホストへ届く途中で行う。平文の書庫はどこにも作らない
- 名前は officeweave-<取得日時>.tar.gz.enc になる
- 取得の直後に、復号して書庫として読めることを確かめる
- 確かめられなければ、書庫を残さず失敗する
```

パスフレーズは、値ではなくファイルの経路で渡す。
値を環境変数で渡すと、そこから呼ぶ子プロセスすべてへ渡り、記録へも写り得る。
ファイルは、読める利用者を運用の担当者だけに限る。

```bash
chmod 600 /etc/officeweave/backup-passphrase
```

パスフレーズは書庫に含まれない。失うと復元できない。
書庫とは別の場所へ保管する。

#### 方式

```text
openssl enc -aes-256-cbc -md sha256 -pbkdf2 -iter 600000 -salt
```

鍵はパスフレーズから導出する。塩は書庫の先頭へ入る。

守るのは内容の秘匿である。改ざんの検知は行わない。
書庫を書き換えられ得る場所へ置く場合は、保管先の権限で守る。

#### 製品を通さずに取り出す

書庫だけが残った状況でも、`openssl` があれば中身を取り出せる。

```bash
openssl enc -d -aes-256-cbc -md sha256 -pbkdf2 -iter 600000 \
  -pass file:/etc/officeweave/backup-passphrase \
  -in backups/officeweave-20260101T000000Z.tar.gz.enc |
  tar --extract --gzip
```

開発環境の `bin/backup` と `bin/restore` は暗号化を扱わない。
暗号化された書庫を開発環境で使う場合は、上の手順で復号してから渡す。

### 保持する数

`BACKUP_KEEP` を指定すると、出力先へ残す書庫の数を上限で抑える。
指定した場合だけ働き、既定値は持たない。指定しなければ書庫は増え続ける。

```bash
BACKUP_KEEP=7 script/production_backup /var/backups/officeweave
```

```text
- 消すのは、取得に成功したあとだけ
- 消すのは、このスクリプトが付けた名前に一致する書庫だけ
- 名前は取得日時で始まるため、古い側から消える
- 消した書庫は標準エラーへ出す。標準出力へ出るのは取得した書庫の経路だけ
- 消せなかった場合は、取得した経路を伝えたうえで 0 以外で終わる
```

出力先を他の用途と共有していても、手で置いた控えや別の製品のファイルは消さない。

日数での保持は用意していない。取得が止まっている間に、
残っている書庫が期限だけで消えることを避けるためである。
日数で管理する場合は、保管先の仕組み側で行う。

### 定期的な取得

取得はホストの時刻起動から呼ぶ。製品側に時刻起動の仕組みは持たない。
`worker` の定期実行にも登録しない。書庫を置くのはホストであり、
コンテナの中からホストのディレクトリへは書き出さない。

無人で呼ぶために、取得は次の 3 つを満たす。

```text
- 取得が重なっていれば、取得せずに 0 以外で終わる
- 記録の各行に時刻が付く
- 取得できなかった場合は 0 以外で終わる
```

#### cron から呼ぶ

```cron
MAILTO=operations@example.com
PATH=/usr/local/bin:/usr/bin:/bin

30 2 * * * cd /srv/officeweave && BACKUP_KEEP=7 BACKUP_PASSPHRASE_FILE=/etc/officeweave/backup-passphrase script/production_backup /var/backups/officeweave >> /var/log/officeweave-backup.log 2>&1
```

```text
- PATH を指定する。cron の既定の PATH に docker が無い環境がある
- リポジトリのルートへ移ってから呼ぶ
- MAILTO を指定すると、失敗した回の記録が届く
```

`>> ... 2>&1` を付けた場合、成功した回の記録もファイルへ残る。
`MAILTO` へ届くのは、出力があった回だけである。

#### systemd timer から呼ぶ

```ini
[Unit]
Description=OfficeWeave のバックアップ

[Service]
Type=oneshot
WorkingDirectory=/srv/officeweave
Environment=BACKUP_KEEP=7
Environment=BACKUP_PASSPHRASE_FILE=/etc/officeweave/backup-passphrase
ExecStart=/srv/officeweave/script/production_backup /var/backups/officeweave
```

```ini
[Unit]
Description=OfficeWeave のバックアップを毎日実行する

[Timer]
OnCalendar=*-*-* 02:30:00
Persistent=true

[Install]
WantedBy=timers.target
```

記録は journal へ入る。失敗した回は `systemctl status` と
`OnFailure=` から拾える。

```bash
journalctl -u officeweave-backup.service --since today
```

#### 取得が重なった場合

取得中は、出力先へ `.production_backup.lock` を作る。
残っているあいだ、次の取得は始まらない。

```text
- 同じホストで、そのプロセスが動いている    取得せずに失敗する
- 同じホストで、そのプロセスが残っていない  印を引き継いで取得する
- 別のホストが作った印                     取得せずに失敗する
- 中身が読めない印                         取得せずに失敗する
```

別のホストの印を奪わない。そのプロセスが動いているかを、別のホストからは
判定できない。判定できないものを奪うと、取得が重なる。

失敗した場合、印の経路と取り除き方を記録へ出す。

```bash
rm -rf /var/backups/officeweave/.production_backup.lock
```

取り除く前に、そのホストで取得が動いていないことを確かめる。

### 保管

- 書庫はアプリケーションと同じホストに置いたままにしない
- 書庫には組織の全データと添付ファイルが含まれる。持ち出しと保管の扱いに注意する
- `backups/` はリポジトリの追跡対象から除いている

## 3. 復元

```bash
script/production_restore backups/officeweave-20260101T000000Z.tar.gz
```

復元先の内容は失われる。取り違えを防ぐため、実行前に確認を求める。
自動で実行する場合は確認を省ける。

```bash
FORCE=1 script/production_restore <書庫のパス>
```

暗号化された書庫は、取得のときと同じパスフレーズを指定する。

```bash
BACKUP_PASSPHRASE_FILE=/etc/officeweave/backup-passphrase \
  script/production_restore backups/officeweave-20260101T000000Z.tar.gz.enc
```

### 復元の進み方

```text
1. ホスト側で、暗号化されているかを書庫の中身から判定する
2. 暗号化されていれば、復号して書庫として読めることを確認する
3. 暗号化されていなければ、そのまま書庫として読めることを確認する
4. 確認を求める（FORCE=1 なら省く）
5. web を停止する
6. 一時コンテナへ書庫を標準入力から渡す。暗号化された書庫は復号して渡す
7. コンテナ内で書庫の中身を検査する
8. 検査を通った場合だけ、データベースとファイルを置き換える
9. 成功した場合だけ web を起動する
10. 稼働確認と診断を実行する
```

停止した `web` へ `docker compose exec` はできない。
そのため、復元は停止した `web` とは別の一時コンテナで実行する。

暗号化されているかは、名前ではなく書庫の中身で判定する。
改名した書庫も、拡張子を落として転送された書庫も、同じように扱える。

復号はホスト側で行う。コンテナへ渡るのは平文の書庫であり、
パスフレーズはコンテナへ渡らない。

パスフレーズを指定しない場合、暗号化された書庫は `web` を停止する前に拒否する。
パスフレーズが違う場合も同じである。どちらも既存のデータは変更されない。

### 受け付けない書庫

次のいずれかに当てはまる書庫は、データベースにもファイルにも触れずに拒否する。

```text
- 書庫として読み取れない
- database.sql が無い、または空
- storage/ が無い
- metadata.txt が無い
- 絶対パスを含む
- 展開先の外を指す経路を含む
```

`queue_database.sql` は必須にしない。形式 2 より前の書庫を受け付けるためである。

拒否した場合、既存のデータは変更されない。

### ファイルの完全な置き換え

復元では、既存の `storage/` の中身をすべて取り除いてから書庫の内容を戻す。
隠しファイルも取り除く。`storage` ディレクトリ自体は残す。

上書きだけで済ませると、書庫に含まれない古いファイルが残り、
削除したはずの添付が復元後に復活する。

### 未処理のジョブの置き換え

復元では、既存の未処理のジョブをすべて取り除いてから書庫の内容を戻す。
残すと、復元した業務データと噛み合わない送信が動き出す。

#### 形式 2 より前の書庫

`queue_database.sql` を含まない書庫も受け付ける。その場合は次のようになる。

```text
- 業務データとファイルは復元される
- ジョブ用の表は作り直される
- 取得時に送信待ちだったメールと Webhook は失われる
```

失われることは、復元時に警告として表示する。

### 復元に失敗した場合

`web` と `worker` は停止したままにする。中途半端なデータで運用を再開させないためである。

```bash
docker compose -f compose.production.yaml logs web
```

```bash
docker compose -f compose.production.yaml logs worker
```

```bash
FORCE=1 script/production_restore <別の書庫>
```

## 4. 確認

復元が成立することを、実際に確認してから運用へ入る。

```text
1. 取得する
2. 記録をひとつ削除する
3. 復元する
4. 削除した記録が戻っていることを確認する
5. 添付ファイルが開けることを確認する
6. 取得後に追加したファイルが残っていないことを確認する
7. 未処理のジョブが取得時点へ戻っていることを確認する
```

取得できているだけでは、復元できることの確認にならない。

## 5. 別のホストへの復元

書庫は接続先に依存しない。別のホストで復元する場合は、
移行を先に実行してから復元する必要はない。書庫にスキーマ定義が含まれる。

ただし、次は書庫に含まれない。復元先で改めて用意する。

```text
.env の内容（接続情報、送信設定、鍵）
config/master.key
```

## 6. 開発環境での取得と復元

開発環境では、コンテナ内で直接実行してよい。ソースコードをホストと共有しているため、
`backups/` へ書き出せばホスト側にも残る。

```bash
docker compose exec web bin/backup
```

```bash
docker compose exec -e FORCE=1 web bin/restore backups/<書庫>
```

コンテナ内の `bin/backup` と `bin/restore` は暗号化を扱わない。
書庫を作る側と保管する側を分けており、暗号化するのは保管する側だけとする。

## 7. 扱っていないこと

次は扱わない。

```text
差分での取得
別のホストへの自動転送
日数での保持
```

日数での保持を用意しない理由は「保持する数」にある。

定期取得の仕組み自体は持たない。呼ぶのはホストの時刻起動とし、
その登録手順を「定期的な取得」へ書いた。
