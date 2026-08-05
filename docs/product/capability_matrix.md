# OfficeWeave 機能到達度

本書は、機能ごとの段階と、そこまでの到達度を持つ。

段階の決め方は [製品範囲](product_scope.md)、状態と条件は [受入条件](acceptance_criteria.md) にある。
`未達` の番号は、受入条件「4. Core に共通の受入条件」の番号を指す。

対象は `4167436` 時点のリポジトリである。
経路は `config/routes.rb` に、模型は `app/models/` にある。

## 1. 読み方

```text
種類  capability / cross_cutting_gate
状態  planned / partial / complete / deferred / rejected
経路  画面と API の入口。持たない機能は「入口」へ運用の入口や定期実行を書く
検証  その機能の退行を止めるテスト。代表的なものを挙げる
文書  操作の手順を読める文書。無い場合は「なし」と書く
未達  受入条件のうち、まだ満たしていないもの
```

種類は 3 つある。本書が持つのは、そのうち 2 つである。

```text
capability          利用者、管理者、運用者が使う機能。本書が持つ
cross_cutting_gate  特定の機能に属さない横断の品質。本書が持つ
release_gate        版全体の検証。受入条件が持つ
```

第 2 節の見出しは、断りがなければ `capability` である。
`cross_cutting_gate` のものだけ、その旨を書く。
次の作業で機械が読む一覧を作るときは、全件が種類を持つようにする。

版全体の検証は、機能ではなく版に属する。機能の一覧へ混ぜると、
どの機能も進んでいないのに一覧だけが伸びる。
[受入条件](acceptance_criteria.md) の「3. 実装済みと本番準備済み」が持つ。

`complete` は現在 1 件である。

次の 2 つは、複数の Core 機能にまたがる横断の課題である。

- 条件 2: 更新の経路に、監査へ記録するかしないかの割り当てが無い
- 条件 7: 増え続ける記録のうち、保持の方針があるのは監査記録だけである

どちらも、横断の仕組みを 1 つ作れば終わるものではない。最後は機能ごと、
記録の種類ごとに割り当てる必要がある。

そして、この 2 つを解消しても `complete` にはならない。機能ごとに、権限の
粒度、一覧の上限、選択欄の描画量、データベースの不変条件、想定規模での実測、
操作の文書といった別の未達が残る。機能ごとの未達は、それぞれの節に書いた。

本番準備済みの機能は無い。判定に使う検証の記録が存在しないためである。

## 2. Core

### ログインとセッション

```text
状態  partial
経路  /session
模型  Session, User, Authentication::*
検証  test/models/session_test.rb, test/controllers/sessions_controller_test.rb,
      test/controllers/session_activity_test.rb, test/system/authentication_test.rb
文書  docs/operations/administration.md, docs/operations/configuration.md
```

未達:

- 7: 期限を過ぎたログインの記録に、削除の方針が無い

### 外部認証

```text
状態  partial
経路  /oidc/session, /oidc/callback
模型  Authentication::OidcClient, Authentication::OidcIdToken
検証  test/controllers/oidc_login_test.rb, test/models/authentication/oidc_client_test.rb,
      test/models/authentication/oidc_id_token_test.rb
文書  docs/development/authentication.md, docs/operations/configuration.md
```

未達:

- 9: 受け取った属性を利用者のどの項目へ結び付けるかが文書に無い
- 実際の認証基盤へ接続した状態での確認が無い

### パスワードの変更と再設定

```text
状態  partial
経路  /password, /password/edit, /password_resets
模型  User, Authentication::PasswordPolicy
検証  test/controllers/password_change_test.rb, test/controllers/password_reset_test.rb,
      test/models/authentication/password_policy_test.rb
文書  docs/operations/administration.md, docs/operations/configuration.md
```

未達:

- 7: 使い終わった再設定の token に、削除の方針が無い

### ログイン中の端末

```text
状態  partial
経路  /logins
模型  Session
検証  test/controllers/logins_controller_test.rb, test/system/authentication_test.rb
文書  docs/operations/administration.md
```

未達:

- 7: ログインとセッションと同じ

### 自分の設定

```text
状態  partial
経路  /settings
模型  User, NotificationPreference
検証  test/controllers/settings_controller_test.rb, test/models/notification_preference_test.rb,
      test/system/settings_test.rb
文書  なし
```

未達:

- 2: 表示言語と配信設定の変更が監査へ残らない
- 9: 利用者がこの画面で何を変えられるかを読める文書が無い

### 利用者の管理

```text
状態  partial
経路  /users, /users/:user_id/activation
模型  User, Organization
検証  test/controllers/users_controller_test.rb, test/controllers/user_activations_controller_test.rb,
      test/models/user_administrator_concurrency_test.rb, test/system/users_test.rb
文書  docs/operations/administration.md
```

未達:

- 権限が管理者と一般利用者の 2 段階しかなく、機能ごとの利用可否を持たない
- 組織そのものの情報を画面から変更できない

### 部門と所属

```text
状態  partial
経路  /departments, /departments/:department_id/memberships
模型  Department, Membership
検証  test/models/department_hierarchy_test.rb, test/controllers/departments_controller_test.rb,
      test/controllers/memberships_controller_test.rb, test/system/departments_test.rb
文書  docs/operations/administration.md
```

未達:

- 4: 一覧に上限が無い
- 5: 所属を足す欄が利用者を全件描く
- 6: 階層の循環をデータベース側で拒否しない

### 利用者と部門の入出力

```text
状態  partial
経路  /data_transfers
模型  CsvTransfer, UserCsv, DepartmentCsv
検証  test/models/user_csv_test.rb, test/models/department_csv_import_test.rb,
      test/controllers/data_transfers_controller_test.rb, test/system/data_transfers_test.rb
文書  docs/operations/administration.md
```

未達:

- 想定規模の件数での実測が無い

### 入口画面

```text
状態  partial
経路  /
模型  Announcement, Request, Department
検証  test/controllers/home_controller_test.rb, test/controllers/home_unread_test.rb,
      test/controllers/home_request_test.rb
文書  なし
```

未達:

- 9: 入口に何が出るかを読める文書が無い

区画が固定であることは未達に数えない。
利用者が区画を選び、並べ替えるのは Suite の拡張であり、Core の条件は
必要な情報と、各機能への入口がそろっていることまでとする。

### お知らせ

```text
状態  partial
経路  /announcements
模型  Announcement, AnnouncementDepartment, AnnouncementRead
検証  test/models/announcement_test.rb, test/controllers/announcements_controller_test.rb,
      test/models/scheduled_announcement_test.rb, test/system/announcements_test.rb
文書  なし
```

未達:

- 2: 作成・変更・削除が監査へ残らない
- 4: 一覧に上限が無い
- 9: 操作を読める文書が無い

### 予定

```text
状態  partial
経路  /events
模型  Event, Event::Recurrence, EventDepartment, EventParticipant
検証  test/models/event_test.rb, test/models/recurring_event_test.rb,
      test/controllers/event_participants_test.rb, test/system/events_test.rb
文書  なし
```

未達:

- 2: 作成・変更・削除が監査へ残らない
- 3: 繰り返しで作る各回が、それぞれ参加者へ通知を作る
- 4: 開始日以降を上限なく並べる
- 5: 参加者と公開範囲の欄が、利用者と部門を全件描く
- 9: 操作を読める文書が無い

### 設備・備品

```text
状態  partial
経路  /resources
模型  Resource
検証  test/models/resource_test.rb, test/controllers/resources_controller_test.rb,
      test/system/resources_test.rb
文書  なし
```

未達:

- 2: 作成・変更が監査へ残らない
- 4: 一覧に上限が無い
- 9: 操作を読める文書が無い

### 設備・備品の予約

```text
状態  partial
経路  /reservations
模型  Reservation
検証  test/models/reservation_test.rb, test/controllers/reservation_change_test.rb,
      test/system/reservations_test.rb
文書  docs/operations/administration.md（重なった場合の対処のみ）
```

未達:

- 2: 作成・変更・取り消しが監査へ残らない
- 4: 開始日以降を上限なく並べる
- 9: 操作を読める文書が無い
- 重なりの判定が、データベースが返す文面に制約名が含まれるかどうかに依存する

### 申請と承認

```text
状態  partial
経路  /requests, /requests/:request_id/submission, /requests/:request_id/decision, /request_types
模型  Request, RequestType, ApprovalStep, RequestApprovalStep, RequestActivity
検証  test/models/multi_step_approval_test.rb, test/models/request_concurrency_test.rb,
      test/controllers/request_decisions_controller_test.rb, test/system/request_decisions_test.rb
文書  docs/operations/administration.md
```

未達:

- 2: 作成・変更・提出・取り下げが監査へ残らない
- 中間の段の承認は、監査に残らないだけでなく応答が失敗し得る。
  `advance_step` は状態を `pending` のまま次の段へ進めるため
  （`app/models/request.rb:184`）、controller が組み立てる監査の action は
  `request_pending` になる（`app/controllers/request_decisions_controller.rb:19`）。
  この値は `AuditEvent::ACTIONS`（`app/models/audit_event.rb:10`）に無く、
  `AuditEvent.record` は `create!` で送出する（同 `:77`）。controller に
  受け止めが無いため、段の進行と履歴を確定したあとで 500 になり得る。
  controller を通した多段の決裁を確かめるテストは無い
- 決裁の権限を、行を確保する前の段に対して判定している
  （`app/controllers/request_decisions_controller.rb:37`、`app/models/request.rb:236`）。
  確保後に読み直した段に対する再判定が無い。並行した決裁で段を飛ばし得る
- 申請の項目が題名と本文だけで、種別ごとの入力欄を持たない
- 経路の種別が直列の承認だけで、全員承認、いずれか 1 人、最終決定、確認を持たない

行を確保したあとの認可、期待した段との一致、段の進行、履歴、代理元、監査を
ひとつの transaction へまとめ、通知は commit のあとへ積む。この 6 つは
別々に直せない。片方だけ直すと、いま失敗している経路が黙って通るようになり、
段を飛ばした記録だけが残る。

### 承認の委任

```text
状態  partial
経路  /approval_delegations
模型  ApprovalDelegation
検証  test/models/approval_delegation_test.rb, test/models/delegated_approval_test.rb,
      test/controllers/approval_delegations_controller_test.rb
文書  docs/operations/administration.md
```

未達:

- 6: 期間の重なりを問い合わせで確かめており、並行して作成すると両方成立し得る

### 文書

```text
状態  partial
経路  /documents, /documents/:document_id/attachments/:id, /document_categories
模型  Document, DocumentCategory, DocumentDepartment
検証  test/models/document_access_test.rb, test/models/document_search_test.rb,
      test/controllers/attachment_delivery_test.rb, test/system/document_access_test.rb
文書  docs/operations/administration.md（添付が開けない場合の対処のみ）
```

未達:

- 2: 作成・変更・削除と、添付の取得が監査へ残らない
- 4: 分類の一覧に上限が無い
- 9: 操作を読める文書が無い
- 階層、版、編集の占有、ごみ箱、容量の把握を持たない

### 通知

```text
状態  partial
経路  /notifications
模型  Notification, NotificationPreference
検証  test/models/notification_test.rb, test/models/notification_delivery_test.rb,
      test/models/notification_batch_delivery_test.rb, test/system/notifications_test.rb
文書  docs/operations/administration.md, docs/operations/configuration.md
```

未達:

- 3: 重複の判定が「宛先・対象・出来事」で、対象ごとに 1 度しか作れない
  （`app/models/notification.rb`）。差し戻しのあとの再提出、同じ利用者が担当する
  後続の段、参加者の外し直しでは、正当な通知が作られない
- 7: 通知に保持の方針が無い
- まとめて既読にする操作が無い

### 監査記録

```text
状態  partial
経路  /audit_events, /audit_events/export
模型  AuditEvent, AuditEventCsv
検証  test/models/audit_event_test.rb, test/models/audit_event_retention_test.rb,
      test/controllers/audit_events_export_test.rb
文書  docs/operations/administration.md, docs/operations/configuration.md
```

未達:

- 2: 記録を残す箇所は 30 で、26 種類の操作を扱う
  （`grep -rn record_audit_event app/controllers`）。
  お知らせ、予定、文書、設備、予約、申請の作成と提出と取り下げ、申請の種別、
  自分の設定には割り当てそのものが無い。
  運用管理は「重要な操作は監査記録として残る」と書いており、実装と一致しない

### 外部接続 API

```text
状態  partial
経路  /api/v1/announcements, /api/v1/events, /api/v1/departments, /api/v1/users, /api_tokens
模型  ApiToken, RateLimitStore, Pagination
検証  test/controllers/api/v1/api_access_test.rb, test/controllers/api/v1/api_paging_test.rb,
      test/controllers/api/v1/api_rate_limit_test.rb, test/models/api_token_scope_test.rb
文書  docs/operations/administration.md
```

未達:

- 範囲が未設定の token を全範囲の許可として扱う（`app/models/api_token.rb`）。
  資源を足すと、過去に発行した token へ自動で開く
- 上限の計数を web の内側に持つ（`app/models/rate_limit_store.rb`）。
  配布用の構成は共有の置き場を持たず、web の数だけ上限が増える
- 応答の形を版として固定した定義が無い
- 読み取りだけで、書き込みの経路が無い

### 出来事の送信

```text
状態  partial
経路  /webhook_endpoints
模型  WebhookEndpoint, WebhookDestination, WebhookDelivery
検証  test/models/webhook_destination_test.rb, test/models/webhook_publishing_test.rb,
      test/jobs/deliver_webhook_job_test.rb
文書  docs/operations/configuration.md, docs/operations/administration.md
```

未達:

- 7: 送信の記録に保持の方針が無い
- 出来事の一覧に予定の招待があるが、外部へ送る経路が見当たらない
- 出来事ごとの形の定義と、その版が無い

### 表示言語

```text
状態  partial
経路  /locale
模型  Localizable（app/controllers/concerns/localizable.rb）
検証  test/configuration/locale_symmetry_test.rb, test/controllers/locale_negotiation_test.rb,
      test/system/locale_switching_test.rb
文書  docs/development/conventions.md
```

未達:

- 2: 表示言語の変更が監査へ残らない
- 9: 利用者向けの切り替え手順が文書に無い

### 画面の到達性

```text
種類  cross_cutting_gate
状態  partial
入口  すべての画面
模型  なし（app/views/ と app/assets/ が対象）
検証  test/system/accessibility_test.rb, test/browser/accessibility_audit_test.rb,
      test/configuration/accessibility_check_test.rb
文書  docs/development/accessibility.md
```

未達:

- 実際の支援技術と実機での確認が無い
- 狭い画面から主要機能へ到達できない。320 px と 400% 拡大での案内も、
  検証の対象に入っていない

### 利用者向けの操作文書

```text
種類  cross_cutting_gate
状態  planned
入口  なし
模型  なし
検証  なし
文書  なし
```

未達:

- 利用者と管理者が操作を学べる文書が無い。共通条件 9 は各機能へ課されるため、
  この文書が無いあいだ、画面を持つ Core 機能はどれも complete にならない

### 稼働確認と診断

```text
状態  complete
経路  /up, /health
入口  bin/diagnose, bin/jobs_status
模型  Diagnostics
検証  test/controllers/health_controller_test.rb, test/models/diagnostics_test.rb,
      test/system/health_test.rb
文書  docs/operations/configuration.md, docs/operations/administration.md
```

未達: なし。

共通条件のうち、満たすものと該当しないものを番号ごとに示す。

```text
1  満たす    認証を要さない経路だが、返すのは依存先への到達可否だけで、
             組織に属する情報を含まない
2  非該当    状態を変えない
3  非該当    通知を作らない。運用異常の通知は別の機能として扱う
4  非該当    一覧を持たない
5  非該当    利用者・部門・設備を選ばせる欄を持たない
6  非該当    記録を持たない
7  非該当    蓄積する記録を残さない
8  満たす    経路、診断の判定、画面からの確認にテストがある
9  満たす    設定と運用管理の両方に手順がある
10 非該当    応答が機械向けの形式で、画面へ出す語句を持たない
11 非該当    操作する画面を持たない
```

### 運用異常の通知

```text
状態  partial
入口  定期実行（ReportOperationalIssuesJob）
模型  OperationalReport, OperationsMailer
検証  test/models/operational_report_test.rb,
      test/jobs/report_operational_issues_job_test.rb
文書  docs/operations/administration.md, docs/operations/configuration.md
```

未達:

- 3: 送信に発生の単位が無い（`app/jobs/report_operational_issues_job.rb`）。
  ジョブを再試行すると、同じ異常が改めて送られる
- 送った記録を残さないため、届かなかったことに運用者が気付けない

### バックアップと復元

```text
状態  partial
入口  bin/backup, bin/restore, script/production_backup, script/production_restore
模型  なし
検証  test/scripts/backup_script_test.rb, test/scripts/restore_script_test.rb,
      test/scripts/production_backup_scripts_test.rb
文書  docs/operations/backup.md
```

未達:

- 改変された保存物を復元の前に拒否しない
- 取得と復元に掛かる時間、停止する時間の実測が無い

### 導入とアップグレード

```text
状態  partial
入口  compose.production.yaml, script/seed_initial_user, bin/setup
模型  InitialUser
検証  test/scripts/setup_script_test.rb, test/scripts/seed_initial_user_script_test.rb,
      test/configuration/container_startup_test.rb
文書  docs/operations/installation.md, docs/operations/upgrade.md
```

未達:

- 新規の導入と、旧版からの更新を同じ commit に対して確かめた記録が無い
- 戻す手順を実際に戻して確かめた記録が無い

## 3. Suite

いずれも経路を持たない。状態はすべて `planned` とする。
着手する順序は GitHub Issue が持つ。

| 機能              | 内容                            |
| --------------- | ----------------------------- |
| 入口の部品配置         | 利用者が入口の区画を選び、並べ替える            |
| 横断検索            | 権限を保ったまま、機能をまたいで探す            |
| 予定の暦表示          | 月・週・日の表示                      |
| 空き時間と出欠         | 参加者の空きの確認と、出欠の返答              |
| 予定の系列           | 繰り返しを系列として持ち、まとめて直す           |
| 設備の時間軸          | 複数の設備の空きを時間軸で見比べる             |
| 文書の階層と権限        | 入れ子の分類と、分類単位の権限               |
| 文書の版とごみ箱        | 版、編集の占有、削除の取り消し               |
| 掲示              | 分類、投稿、返信、購読                   |
| 機能別の運用権限        | 機能ごとの利用可否と運用管理者               |
| 内部メッセージ         | 宛先を指定した連絡と、その一覧               |
| 個人メモ            | 本人だけが読む記録                     |
| ToDo            | 期限と状態を持つ自分の作業                 |
| 在席と電話メモ         | 在席の状態と、受けた連絡の伝達               |
| アドレス帳           | 組織の内外の連絡先                     |
| リンク集            | よく使う宛先の共有                     |
| 報告              | 定型の報告と、その閲覧範囲                 |
| プロジェクト          | 期間、担当、作業の進行                   |
| 申請の様式と経路の種別     | 種別ごとの入力欄と、承認以外の経路             |

## 4. Extended

採否を決めていない領域である。状態はすべて `deferred` とする。
着手の前に [決定記録](../decisions) を残す。

| 領域        | 決める必要があること                    |
| --------- | ----------------------------- |
| メールの送受信   | 自前で持つか、外部の実装との連携に留めるか         |
| 打刻        | 制度対応の負担を負うか、在席の記録に留めるか        |
| 任意の業務アプリ  | 利用者が定義を作る仕組みを持つか              |
| 端末側での継続利用 | 接続が無い状態での利用を対象に含めるか           |

## 5. 範囲外

[製品ビジョン](../vision.md) の非目標に挙がる領域である。状態はすべて `rejected` とする。
一覧は製品ビジョンの非目標と 1 対 1 で対応させる。含める場合は、先に製品ビジョンを更新する。

| 領域        | 範囲へ含めない理由                       |
| --------- | ------------------------------- |
| チャット製品    | 常時接続と即時性を前提とし、この製品の運用形態と要件が異なる  |
| ビデオ会議     | 同上に加えて、通信経路と帯域の運用を製品が負うことになる    |
| 共同文書編集    | 同時編集の解決を自前で持つと、単独の製品に相当する量になる   |
| マイクロサービス構成 | 運用の担当が 1 名前後という前提に対して、運用の負担が過大  |
| 常設の公開サービス | 提供形態をセルフホストに置くという方針と両立しない       |

Suite の内部メッセージは、宛先を指定した連絡を記録として残す機能である。
常時接続、入力中の表示、既読の即時反映は持たない。この点でチャット製品とは別物として扱う。

## 6. 経路の網羅

`config/routes.rb` にあるすべての経路が、第 2 節のいずれかへ属する。
経路を足したときは、属する機能を同じ変更で決める。

属する機能が無い経路は、機能を先に決めるまで足さない。
