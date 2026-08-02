# OfficeWeave 実行キュー

本書は [ロードマップ](roadmap.md) の各 Phase を、独立して検証できるタスクへ分解した一覧である。
上から順に 1 件ずつ実行する。

各タスクは 1 ブランチ 1 PR に対応する。
状態は `完了` `進行中` `未着手` のいずれかとし、マージのたびに更新する。

現在地と実行順の正本は本書だけとする。README とロードマップへは複製しない。

## 現在地

```text
現在の Phase: R2
直近完了 Task: R2-T7
進行中:        なし
次に実行:      R2-T8
```

## P0 プロジェクト契約

| Task  | ブランチ                       | 内容                        | 完了条件                          | 状態  |
| ----- | -------------------------- | ------------------------- | ----------------------------- | --- |
| P0-T1 | `p0/t1-project-foundation` | プロジェクト契約とロードマップを文書化する     | 4 文書が存在し、README から到達できる       | 完了  |
| P0-T2 | `p0/t2-execution-queue`    | ロードマップを改訂し、実行キューを記録する     | CI の位置づけ変更と全 Phase の分解が記録される  | 完了  |
| P0-T3 | `p0/t3-license`            | OSS ライセンスと商標方針を決定する       | `LICENSE` が存在し、方針が文書化される      | 完了  |
| P0-T4 | `p0/t4-tech-stack`         | 技術バージョンの選定基準と候補を固定する      | 基準、対象系列、更新方針、候補が記録される         | 完了  |

## P1 ローカル開発基盤

| Task  | ブランチ                     | 内容                                 | 完了条件                              | 状態  |
| ----- | ------------------------ | ---------------------------------- | --------------------------------- | --- |
| P1-T1 | `p1/t1-app-skeleton`     | Rails アプリケーションとコンテナ構成を作成し、DB へ接続する | コンテナが起動し、DB 接続が確認できる              | 完了  |
| P1-T2 | `p1/t2-dev-commands`     | 標準 bin コマンドと起動手順を整備する              | 第三者が README の手順だけで起動できる           | 完了  |
| P1-T3 | `p1/t3-health-endpoint`  | 稼働確認用エンドポイントと環境変数を整理する             | 稼働確認が HTTP で取得でき、必須環境変数が文書化される    | 完了  |

## P2 品質基盤（ローカル実行のみ）

| Task  | ブランチ                    | 内容                        | 完了条件                       | 状態  |
| ----- | ----------------------- | ------------------------- | -------------------------- | --- |
| P2-T1 | `p2/t1-test-foundation` | テスト基盤を整備する                | 単体テストとシステムテストが実行できる        | 完了  |
| P2-T2 | `p2/t2-lint`            | Lint を導入する                | 全ファイルで指摘なしに実行できる           | 完了  |
| P2-T3 | `p2/t3-security-audit`  | セキュリティ検査と依存監査を導入する        | 検査と監査が実行でき、既知の脆弱性が 0 件     | 完了  |
| P2-T4 | `p2/t4-verify-command`  | 一括検証コマンドを追加する             | 1 コマンドで全検証が実行できる           | 完了  |

## P3 UI・多言語基盤

| Task  | ブランチ                     | 内容                          | 完了条件                             | 状態  |
| ----- | ------------------------ | --------------------------- | -------------------------------- | --- |
| P3-T1 | `p3/t1-layout-css`       | 基本レイアウトと素の CSS を実装する        | 設計トークンとレイアウトが適用される               | 完了  |
| P3-T2 | `p3/t2-i18n`             | 日本語・英語対応と言語切替を実装する          | 画面文字列が両言語で表示され、切替が JavaScript なしで動作する | 完了  |
| P3-T3 | `p3/t3-accessibility`    | アクセシビリティの基本要件を満たす           | ランドマーク、スキップリンク、フォーカス表示が機能する      | 完了  |

## P4 Identity

| Task  | ブランチ                        | 内容                    | 完了条件                         | 状態  |
| ----- | --------------------------- | --------------------- | ---------------------------- | --- |
| P4-T1 | `p4/t1-authentication`      | 利用者とログイン・ログアウトを実装する   | 認証済み利用者だけが保護画面へ到達できる         | 完了  |
| P4-T2 | `p4/t2-organization`        | 組織、部門、所属を実装する         | 利用者が部門へ所属でき、一覧で確認できる         | 完了  |
| P4-T3 | `p4/t3-authorization`       | 必要最小限の権限を実装する         | 管理者専用操作が一般利用者から実行できない        | 完了  |
| P4-T4 | `p4/t4-user-management`     | 管理者向けの利用者管理画面を実装する    | 管理者が利用者を作成・更新・無効化できる         | 完了  |

## P5 Portal

| Task  | ブランチ                      | 内容                | 完了条件                        | 状態  |
| ----- | ------------------------- | ----------------- | --------------------------- | --- |
| P5-T1 | `p5/t1-portal-home`       | ホームとナビゲーションを実装する  | ログイン後にホームが表示され、各機能へ遷移できる    | 完了  |
| P5-T2 | `p5/t2-announcements`     | お知らせと公開範囲を実装する    | 公開範囲外の利用者にお知らせが表示されない       | 完了  |
| P5-T3 | `p5/t3-read-state`        | 既読管理を実装する         | 既読が記録され、ホームで未読が判別できる        | 完了  |

## P6 Calendar

| Task  | ブランチ                   | 内容                | 完了条件                         | 状態  |
| ----- | ---------------------- | ----------------- | ---------------------------- | --- |
| P6-T1 | `p6/t1-events`         | 個人予定と共有予定を実装する    | 予定を登録でき、公開範囲に応じて表示が変わる       | 完了  |
| P6-T2 | `p6/t2-resources`      | 設備・備品を実装する        | 設備・備品を登録し、一覧で確認できる           | 完了  |
| P6-T3 | `p6/t3-reservations`   | 予約と重複防止を実装する      | 同一設備の時間帯重複がデータベース側で拒否される     | 完了  |

## P7 Requests

| Task  | ブランチ                    | 内容              | 完了条件                        | 状態  |
| ----- | ----------------------- | --------------- | --------------------------- | --- |
| P7-T1 | `p7/t1-request-types`   | 申請種別と申請を実装する    | 申請を作成し、状態が記録される             | 完了  |
| P7-T2 | `p7/t2-approval`        | 承認と差し戻しを実装する    | 承認者だけが承認・差し戻しでき、状態が遷移する     | 完了  |
| P7-T3 | `p7/t3-request-history` | 申請の一覧と担当分の把握を整える | 承認待ちの担当分を見落とさずに把握できる          | 完了  |

## P8 Documents

| Task  | ブランチ                     | 内容                          | 完了条件                        | 状態  |
| ----- | ------------------------ | --------------------------- | --------------------------- | --- |
| P8-T1 | `p8/t1-documents`        | 文書と分類を実装する                  | 文書を作成し、分類で絞り込める             | 完了  |
| P8-T2 | `p8/t2-attachments`      | 添付ファイルを実装する                 | ファイルを添付し、再取得できる             | 完了  |
| P8-T3 | `p8/t3-document-access`  | 文書のアクセス制御を実装する              | 権限のない利用者が文書へ到達できない          | 完了  |
| P8-T4 | `p8/t4-search`           | データベース機能だけで全文検索を実装する        | 日本語と英語の語句で文書を検索できる          | 完了  |

## P9 Notifications

| Task  | ブランチ                            | 内容             | 完了条件                     | 状態  |
| ----- | ------------------------------- | -------------- | ------------------------ | --- |
| P9-T1 | `p9/t1-in-app-notifications`    | アプリ内通知を実装する    | 対象操作で通知が作成され、一覧で確認できる    | 完了  |
| P9-T2 | `p9/t2-mail-notifications`      | メール通知を実装する     | 開発環境で送信内容を確認できる          | 完了  |
| P9-T3 | `p9/t3-notification-settings`   | 配信設定を実装する      | 利用者ごとに通知の有効・無効を切り替えられる   | 完了  |

## P10 Integrations

| Task   | ブランチ                    | 内容               | 完了条件                        | 状態  |
| ------ | ----------------------- | ---------------- | --------------------------- | --- |
| P10-T1 | `p10/t1-rest-api`       | 最小 REST API を実装する | トークン認証で主要リソースを取得できる         | 完了  |
| P10-T2 | `p10/t2-webhooks`       | Webhook を実装する    | 登録した宛先へイベントが送信される           | 完了  |
| P10-T3 | `p10/t3-external-auth`  | 外部認証の拡張境界を用意する   | 認証方式を差し替えられる境界が存在し、既定は内部認証   | 完了  |
| P10-T4 | `p10/t4-csv`            | CSV 入出力を実装する     | 利用者と組織を CSV で入出力できる          | 完了  |

## P11 Operations

| Task   | ブランチ                     | 内容                | 完了条件                        | 状態  |
| ------ | ------------------------ | ----------------- | --------------------------- | --- |
| P11-T1 | `p11/t1-audit-events`    | 監査イベントを実装する       | 重要操作が監査イベントとして記録される         | 完了  |
| P11-T2 | `p11/t2-backup-restore`  | バックアップと復元を実装する    | 取得したバックアップから復元し、データが一致する    | 完了  |
| P11-T3 | `p11/t3-diagnostics`     | アップグレードと運用診断を整備する | 診断コマンドが構成の問題を検出できる          | 完了  |

## P12 Self-host release

| Task   | ブランチ                       | 内容              | 完了条件                        | 状態  |
| ------ | -------------------------- | --------------- | --------------------------- | --- |
| P12-T1 | `p12/t1-demo-data`         | デモデータを用意する      | 1 コマンドで動作確認用データを投入できる       | 完了  |
| P12-T2 | `p12/t2-operation-docs`    | 導入・運用文書を整備する    | 導入、設定、運用、復旧の手順が文書化される       | 完了  |
| P12-T3 | `p12/t3-selfhost-package`  | セルフホスト配布構成を用意する | 配布用の構成でクリーン環境から起動できる        | 完了  |
| P12-T4 | `p12/t4-release-prep`      | 初回リリース準備を行う     | 版数、変更履歴、公開手順が整う             | 完了  |

## F 最終検証と CI

| Task | ブランチ                | 内容            | 完了条件                              | 状態  |
| ---- | ------------------- | ------------- | --------------------------------- | --- |
| F-T1 | `f/t1-ci`           | CI を導入する      | 既存の検証コマンドが CI で成功する               | 完了  |
| F-T2 | `f/t2-final-verify` | 総合検証を実施する     | クリーン環境からの起動、バックアップ復元、主要 E2E が成功する | 完了  |

## R0 安定化

F 完了後の静的レビューで確認した不具合を、GitHub Issue として登録した。
本 Phase では、それらを重大度と依存関係の順に修正する。新しい機能は足さない。

原則として 1 つの不具合契約につき 1 Issue とする。
1 PR は 1 つの原子的な修正単位とする。
複数 Issue が同じ原因・同じトランザクション境界・同じ回帰テスト群を共有する場合は、
理由を本書と PR 本文へ記録したうえで、1 PR から複数 Issue を閉じてよい。
Issue が大きい場合は分割してよいが、分割した場合は本書へ追記してから実装へ入る。

| Task   | ブランチ                       | 対応 Issue                                                       | 内容                             | 状態  |
| ------ | -------------------------- | -------------------------------------------------------------- | ------------------------------ | --- |
| R0-T0  | `r0/t0-stabilization-roadmap` | —                                                            | 不具合 Issue を登録し、安定化フェーズを記録する     | 完了  |
| R0-T1  | `r0/t1-compose-isolation`  | [#48](https://github.com/toshtag/OfficeWeave/issues/48)         | Docker 構成・データボリューム・ポートを分離する    | 完了  |
| R0-T2  | `r0/t2-backup-restore`     | [#49](https://github.com/toshtag/OfficeWeave/issues/49)         | バックアップの永続化と復元手順を成立させる          | 完了  |
| R0-T3  | `r0/t3-webhook-ssrf`       | [#50](https://github.com/toshtag/OfficeWeave/issues/50)         | Webhook 送信先を制限し SSRF を塞ぐ       | 完了  |
| R0-T4  | `r0/t4-persistent-jobs`    | [#51](https://github.com/toshtag/OfficeWeave/issues/51)         | 永続キューとワーカーを導入する                | 完了  |
| R0-T5  | `r0/t5-active-storage-routes` | [#52](https://github.com/toshtag/OfficeWeave/issues/52)      | Active Storage 標準ルートを無効化する     | 完了  |
| R0-T6  | `r0/t6-document-attachments` | [#53](https://github.com/toshtag/OfficeWeave/issues/53) [#75](https://github.com/toshtag/OfficeWeave/issues/75) | 文書更新時の添付追加・選択削除を原子的に扱う         | 完了  |
| R0-T6A | `r0/t6a-active-storage-public-api` | [#77](https://github.com/toshtag/OfficeWeave/issues/77)   | 文書添付更新を公開 API だけで完結させる         | 完了  |
| R0-T7  | `r0/t7-unknown-department-codes` | [#60](https://github.com/toshtag/OfficeWeave/issues/60)   | CSV の未知の部門コードを誤りとして扱う          | 完了  |
| R0-T8  | `r0/t8-active-administrator-invariant` | [#55](https://github.com/toshtag/OfficeWeave/issues/55) | 最後の有効な管理者を失う操作を全経路で拒否する        | 完了  |
| R0-T9  | `r0/t9-auth-provider-fail-closed` | [#56](https://github.com/toshtag/OfficeWeave/issues/56)  | 未知の認証方式を起動時に失敗させる              | 完了  |
| R0-T9A | `r0/t9a-auth-provider-name-collision` | [#83](https://github.com/toshtag/OfficeWeave/issues/83) | 認証方式の登録名衝突を拒否する               | 完了  |
| R0-T10 | `r0/t10-session-boundaries` | [#57](https://github.com/toshtag/OfficeWeave/issues/57)        | セッションへ期限を設け、戻り先と Host を制限する    | 完了  |
| R0-T11 | `r0/t11-csv-formula-injection` | [#61](https://github.com/toshtag/OfficeWeave/issues/61)     | CSV 出力を数式インジェクションから守る          | 完了  |
| R0-T12 | `r0/t12-request-transition-lock` | [#54](https://github.com/toshtag/OfficeWeave/issues/54)   | 申請の決裁を行ロックで直列化する               | 完了  |
| R0-T13 | `r0/t13-password-policy`   | [#66](https://github.com/toshtag/OfficeWeave/issues/66)         | パスワードの最低要件と初期値検査を追加する          | 完了  |
| R0-T13A | `r0/t13a-diagnostics-closeout` | [#81](https://github.com/toshtag/OfficeWeave/issues/81)     | 保存先診断の修正を検証し、Issue と実行キューを完了状態へ揃える | 完了  |
| R0-T14 | `r0/t14-api-token-revocation` | [#65](https://github.com/toshtag/OfficeWeave/issues/65)      | 利用者の無効化で API トークンを失効させる        | 完了  |
| R0-T15 | `r0/t15-reservation-organization-integrity` | [#58](https://github.com/toshtag/OfficeWeave/issues/58) | 予約の組織整合性を検証する                  | 完了  |
| R0-T15A | `r0/t15a-organization-boundary` | [#91](https://github.com/toshtag/OfficeWeave/issues/91)   | 組織をまたぐ参照の検証を他の模型へ広げる          | 完了  |
| R0-T15B | `r0/t15b-concurrency-wait` | [#93](https://github.com/toshtag/OfficeWeave/issues/93)        | 並行実行テストの待ちグラフ観測を安定させる          | 完了  |
| R0-T16 | `r0/t16-settings-transaction` | [#62](https://github.com/toshtag/OfficeWeave/issues/62)      | 設定更新をひとつのトランザクションにまとめる         | 完了  |
| R0-T17 | `r0/t17-api-datetime-validation` | [#63](https://github.com/toshtag/OfficeWeave/issues/63)   | API の不正な日時入力を 400 で返す         | 完了  |
| R0-T17A | `r0/t17a-list-date-range` | [#97](https://github.com/toshtag/OfficeWeave/issues/97)         | 画面の一覧で範囲外の日付を拒む             | 完了  |
| R0-T17B | `r0/t17b-nontransactional-cleanup` | [#98](https://github.com/toshtag/OfficeWeave/issues/98) | 非トランザクションのテストの後片付けをそろえる      | 完了  |
| R0-T17C | `r0/t17c-boot-wait`       | [#99](https://github.com/toshtag/OfficeWeave/issues/99)         | 別プロセスの起動待ちを実行環境の速さから切り離す     | 完了  |
| R0-T18 | `r0/t18-initial-user-scope` | [#64](https://github.com/toshtag/OfficeWeave/issues/64)        | 初期利用者の存在判定を組織単位にする             | 完了  |
| R0-T19 | `r0/t19-scheduled-announcements` | [#59](https://github.com/toshtag/OfficeWeave/issues/59)   | 公開待ちのお知らせを表示し、公開時に通知する         | 完了  |
| R0-T20 | `r0/t20-returned-translation-key` | [#67](https://github.com/toshtag/OfficeWeave/issues/67)  | 差し戻し通知の翻訳キーの誤記を修正する            | 完了  |
| R0-T20A | `r0/t20a-mail-test-constant` | [#106](https://github.com/toshtag/OfficeWeave/issues/106)   | メール送信テストの定数依存を実行順から切り離す      | 完了  |
| R0-T21 | `r0/t21-stabilization-audit` | —                                                             | 安定化完了監査。全 Issue、全検証、文書、配布構成の整合を確認する | 完了  |
| R0-T22 | `r0/t22-password-change-session-revocation` | [#110](https://github.com/toshtag/OfficeWeave/issues/110) | パスワードの変更で進行中のセッションを終わらせる | 完了  |
| R0-T23 | `r0/t23-plain-text-body-rendering` | [#111](https://github.com/toshtag/OfficeWeave/issues/111) | 利用者が入力した本文を平文として描画する      | 完了  |
| R0-T24 | `r0/t24-webhook-endpoint-update-audit` | [#112](https://github.com/toshtag/OfficeWeave/issues/112) | Webhook 宛先の変更を監査記録へ残す        | 完了  |
| R0-T25 | `r0/t25-reservation-event-visibility` | [#113](https://github.com/toshtag/OfficeWeave/issues/113) | 予約に結び付ける予定を参照できるものへ限る     | 完了  |
| R0-T26 | `r0/t26-security-review-closeout` | —                                                             | セキュリティレビュー分の完了確認。Issue と本書の状態を実装結果へ合わせる | 完了  |
| R0-T27 | `r0/t27-notification-batch-delivery` | [#119](https://github.com/toshtag/OfficeWeave/issues/119) | 通知の作成を受け手ごとの問い合わせから切り離す | 完了  |
| R0-T28 | `r0/t28-department-path-preload` | [#121](https://github.com/toshtag/OfficeWeave/issues/121) | 部門の階層表示を 1 回の問い合わせで組み立てる | 完了  |
| R0-T29 | `r0/t29-primary-department-preload` | [#120](https://github.com/toshtag/OfficeWeave/issues/120) | 主たる所属を先読みできる関連にする | 完了  |
| R0-T30 | `r0/t30-home-unread-scope` | [#122](https://github.com/toshtag/OfficeWeave/issues/122) | 入口の未読の判定を表示するぶんへ限る | 完了  |
| R0-T31 | `r0/t31-activity-write-interval` | [#123](https://github.com/toshtag/OfficeWeave/issues/123) | 最終利用時刻の書き込みを要求ごとから間引く | 完了  |
| R0-T32 | `r0/t32-announcement-author-preload` | [#124](https://github.com/toshtag/OfficeWeave/issues/124) | お知らせ一覧の 3 区分で作成者の読み込みをそろえる | 完了  |
| R0-T33 | `r0/t33-performance-review-closeout` | —                                                             | 性能レビュー分の完了確認。Issue と本書の状態を実装結果へ合わせる | 完了  |

## R1 運用信頼性

[ロードマップ](roadmap.md) の R1 を、単独で検証できる単位へ分解した。
機能の追加であるため、GitHub Issue では管理しない。

バックアップは、書庫の整理、書庫の暗号化、時刻起動からの取得の 3 つに分ける。
1 つの PR で扱うと、暗号化した書庫を整理できているかどうかを、取得の入口の
変更と切り離して確かめられない。

記録と書庫を消す機能は、上限を明示した組織だけで働かせる。既定は持たない。

| Task  | ブランチ                        | 対応 Issue | 内容                          | 状態  |
| ----- | --------------------------- | -------- | --------------------------- | --- |
| R1-T1 | `r1/t1-backup-retention`    | —        | 取得した書庫の保持の上限を設ける            | 完了  |
| R1-T2 | `r1/t2-backup-encryption`   | —        | 書庫を暗号化して取得し、同じ経路で復元する       | 完了  |
| R1-T3 | `r1/t3-scheduled-backup`    | —        | 時刻起動から無人で取得できるようにする         | 完了  |
| R1-T4 | `r1/t4-audit-retention`     | —        | 監査記録の保持期間を設ける               | 完了  |
| R1-T5 | `r1/t5-audit-export`        | —        | 監査記録を書き出せるようにする             | 完了  |
| R1-T6 | `r1/t6-structured-log`      | —        | 要求と送信の記録を構造化して出す            | 完了  |
| R1-T7 | `r1/t7-operational-alerts`  | —        | 稼働の異常を運用者へ知らせる              | 完了  |

## R2 認証・アカウント

[ロードマップ](roadmap.md) の R2 を、単独で検証できる単位へ分解した。
機能の追加であるため、GitHub Issue では管理しない。

資格情報の扱いから先に進める。自分で変更できる状態を作ってから、
思い出せない場合の再設定へ進む。順序を逆にすると、再設定だけが
資格情報を変える唯一の経路になり、その経路の重みが上がる。

外部の認証方式へ切り替えた環境では、パスワードに関わる経路を出さない。

OIDC 連携は 3 つに分ける。設定と id_token の検証、認可サーバーとの通信、
そしてログインの経路である。1 つの PR で扱うと、検証と通信が正しいかどうかを、
画面とセッションの開始の変更と切り離して確かめられない。

| Task  | ブランチ                          | 対応 Issue | 内容                            | 状態  |
| ----- | ----------------------------- | -------- | ----------------------------- | --- |
| R2-T1 | `r2/t1-password-change`       | —        | 自分でパスワードを変更できるようにする           | 完了  |
| R2-T2 | `r2/t2-password-reset`        | —        | パスワードの再設定を用意する                | 完了  |
| R2-T3 | `r2/t3-session-management`    | —        | 自分のログインを一覧し、まとめて終わらせる         | 完了  |
| R2-T4 | `r2/t4-api-token-expiry`      | —        | API トークンに有効期限を設ける             | 完了  |
| R2-T5 | `r2/t5-api-token-scope`       | —        | API トークンに権限を設ける               | 完了  |
| R2-T6A | `r2/t6a-health-storage-check` | —       | 保存先が未作成でも稼働確認が通るようにする        | 完了  |
| R2-T6 | `r2/t6-oidc-verification`     | —        | OIDC の設定と id_token の検証を用意する    | 完了  |
| R2-T7A | `r2/t7a-health-probe-isolation` | —      | 稼働確認のテストを並列実行から切り離す         | 完了  |
| R2-T7 | `r2/t7-oidc-client`           | —        | 認可サーバーとの通信を用意する               | 完了  |
| R2-T8 | `r2/t8-oidc-login`            | —        | OIDC でログインできるようにする             | 未着手 |

## R6 保守性

R0 の完了後に行った保守性のレビューで確認した問題を、GitHub Issue として登録した。
本 Phase では、それらを重複の広さと、追随を誤ったときの実害の大きさの順に処理する。

利用者に見える振る舞いを変えない。
変える必要が生じた場合は、本 Phase では扱わず別に登録する。

| Task  | ブランチ                                  | 対応 Issue                                                  | 内容                     | 状態  |
| ----- | ------------------------------------- | --------------------------------------------------------- | ---------------------- | --- |
| R6-T1 | `r6/t1-document-implementation-drift` | [#136](https://github.com/toshtag/OfficeWeave/issues/136) | 規約と品質基盤の文書を実装へそろえる     | 完了  |
| R6-T2 | `r6/t2-environment-documentation`     | [#133](https://github.com/toshtag/OfficeWeave/issues/133) | 環境変数の説明の正本を 1 か所へ定める   | 完了  |
| R6-T3 | `r6/t3-form-field-helper`             | [#132](https://github.com/toshtag/OfficeWeave/issues/132) | 入力欄の組み立てを 1 か所へまとめる    | 完了  |
| R6-T4 | `r6/t4-test-layers`                   | [#137](https://github.com/toshtag/OfficeWeave/issues/137) | テストの置き場所を方針の層へそろえる     | 完了  |
| R6-T5 | `r6/t5-verification-scope`            | [#134](https://github.com/toshtag/OfficeWeave/issues/134) | 総合検証を自動で確かめられないものへ絞る   | 完了  |
| R6-T6 | `r6/t6-execution-queue-scope`         | [#135](https://github.com/toshtag/OfficeWeave/issues/135) | 実行キューを現在地とタスク表へ絞る      | 完了  |

## R7 脆弱性対応

セキュリティレビューで確認したものを、非公開の Draft Security Advisory として
登録した。本 Phase では、それらを 1 件ずつ修正する。

公開の Issue では管理しない。対応する Advisory の番号だけを記録する。
再現手順と影響は Advisory が持ち、本書へは写さない。

1 件の Advisory が、単独で検証できる単位を複数持つことがある。
その場合はタスクを分け、同じ GHSA ID を並べる。Advisory は、
その全タスクが完了した時点で修正済みとして扱う。

| Task  | ブランチ                                  | 対応 Advisory        | 内容                          | 状態  |
| ----- | ------------------------------------- | ------------------ | --------------------------- | --- |
| R7-T1 | `r7/t1-unsubmitted-request-visibility` | GHSA-g3x9-9grv-p8j4 | 未提出の申請を承認担当者の参照範囲から外す       | 完了  |
| R7-T2 | `r7/t2-resolver-process-isolation`    | GHSA-hr7m-r3hx-gj9x | 名前解決の時間切れで実行単位を確実に回収する      | 完了  |
| R7-T3 | `r7/t3-special-purpose-ip-ranges`     | GHSA-jmmg-cxhh-6556 | 特殊用途の IP 範囲を送信先から外す        | 完了  |
| R7-T4 | `r7/t4-webhook-response-limit`        | GHSA-3xmf-2x95-gfmp | Webhook の応答を読む量に上限を設ける      | 完了  |
| R7-T5 | `r7/t5-webhook-total-deadline`        | GHSA-3xmf-2x95-gfmp | Webhook の送信に通信全体の期限を設ける     | 完了  |
| R7-T6 | `r7/t6-response-receive-limit`         | GHSA-3xmf-2x95-gfmp | 応答として受け取る量そのものに上限を設ける   | 完了  |
| R7-T7 | `r7/t7-safe-delivery-error-message`    | GHSA-3xmf-2x95-gfmp | 通信の失敗の記録を決めた文面へそろえる     | 完了  |
| R7-T8 | `r7/t8-deadline-recheck`               | GHSA-3xmf-2x95-gfmp | 期限が守られるかを測り直す           | 完了  |
| R7-T9 | `r7/t9-https-and-receive-boundary`      | GHSA-3xmf-2x95-gfmp | HTTPS の経路と受け取りの境目を固定する   | 完了  |

## R8 性能

R7 の完了後に行った性能のレビューで確認した問題を、GitHub Issue として登録した。
本 Phase では、それらを実測した影響の大きさと、修正の独立性の順に処理する。

推測では着手しない。問い合わせの件数、読み込んだ行、または実行計画で
再現を確かめたものだけを扱う。

| Task  | ブランチ                            | 対応 Issue                                                  | 内容                        | 状態  |
| ----- | ------------------------------- | --------------------------------------------------------- | ------------------------- | --- |
| R8-T1 | `r8/t1-mail-fanout-preload`     | [#154](https://github.com/toshtag/OfficeWeave/issues/154) | メール配信の展開で利用者と配信設定を先読みする   | 完了  |
| R8-T2 | `r8/t2-document-list-projection` | [#155](https://github.com/toshtag/OfficeWeave/issues/155) | 文書一覧を表示に必要な列と関連へ絞る        | 完了  |
| R8-T3 | `r8/t3-home-request-scope`      | [#156](https://github.com/toshtag/OfficeWeave/issues/156) | 入口の申請を表示するぶんへ限る           | 完了  |
| R8-T4 | `r8/t4-unread-notification-index` | [#157](https://github.com/toshtag/OfficeWeave/issues/157) | 未読の通知件数に部分索引を置く          | 完了  |
| R8-T5 | `r8/t5-event-ends-at-index`     | [#158](https://github.com/toshtag/OfficeWeave/issues/158) | 予定の終了時刻の絞り込みに索引を置く       | 完了  |
| R8-T6 | `r8/t6-reservation-ends-at-index` | [#159](https://github.com/toshtag/OfficeWeave/issues/159) | 予約の終了時刻の絞り込みに索引を置く       | 完了  |

## R9 開発体験

R8 の完了後に行った開発体験のレビューで確認した問題を、GitHub Issue として登録した。
本 Phase では、それらを影響する範囲の広さと、修正の独立性の順に処理する。

削る量では判断しない。現在かかっている保守の手間、変更時の二重作業、
更新を落としたときの危険、コマンドの実際の挙動を根拠にする。

| Task  | ブランチ                             | 対応 Issue                                                  | 内容                          | 状態  |
| ----- | -------------------------------- | --------------------------------------------------------- | --------------------------- | --- |
| R9-T1 | `r9/t1-importmap-removal`        | [#166](https://github.com/toshtag/OfficeWeave/issues/166) | 使っていない配信スクリプトの基盤を取り除く       | 完了  |
| R9-T2 | `r9/t2-organization-code-contract` | [#167](https://github.com/toshtag/OfficeWeave/issues/167) | 組織内の識別子の契約を 1 か所へまとめる       | 完了  |
| R9-T3 | `r9/t3-setup-command-contract`   | [#168](https://github.com/toshtag/OfficeWeave/issues/168) | 準備コマンドを準備だけで終わるようにする        | 完了  |
| R9-T4 | `r9/t4-generated-template-cleanup` | [#169](https://github.com/toshtag/OfficeWeave/issues/169) | 実行されない生成雛形と役目を終えた .keep を消す | 完了  |
| R9-T5 | `r9/t5-dependency-review-source` | [#170](https://github.com/toshtag/OfficeWeave/issues/170) | 依存追加の審査手順の正本を 1 つに定める       | 完了  |
| R9-T6 | `r9/t6-development-database-reset` | [#176](https://github.com/toshtag/OfficeWeave/issues/176) | 標準の開発構成からデータベースを安全に再作成できるようにする | 完了  |
| R9-T7 | `r9/t7-placeholder-check-in-ci`  | [#178](https://github.com/toshtag/OfficeWeave/issues/178) | 生成物の検査を取得したままの作業ツリーで成立させる | 完了  |

## 分解の方針

- 1 タスクは、単独でテストまたは動作確認ができる単位までとする
- 画面、モデル、権限をまたぐ機能は、垂直に薄く通す形で 1 タスクにする
- 同じ Phase 内でも、後続タスクが前のタスクの成果に依存してよい
- タスクの追加や分割が必要になった場合は、実装前に本書を更新する
- 網羅性を目的とせず、前後の機能と接続された最小の実装で完了とする

## 本書に書かないもの

本書に置くのは、現在地、Phase ごとのタスク表、分解の方針だけとする。

済んだ判断の記録は置かない。置く先は次のとおりである。

```text
タスクをその順に並べた理由      PR の本文
完了時点で確かめたことの記録    PR の本文と、その実行結果
実装上の判断とその根拠          実装またはテストのコメント
版ごとの変更点                  CHANGELOG.md
不具合そのものの内容            GitHub Issue
```

いずれも、その場に残り `git log` から辿れる。本書へ写すと、同じ内容を
2 か所で保つことになり、本書は現在地を読み取れない分量になる。
実際、R0 の完了記録だけで 238 行あった。

## 新しい Phase を始めるとき

1. [ロードマップ](roadmap.md) の Phase 一覧へ加え、その Phase の節を書く
2. 本書へタスク表を足し、状態を `未着手` にする
3. 現在地を更新してから、最初のタスクへ入る

タスク表の列は `Task` `ブランチ` `対応 Issue` `内容` `状態` とする。
Issue を持たないタスクは `対応 Issue` を `—` とする。

脆弱性のように公開の Issue で管理しないものは、3 列目を対応する登録先へ置き換える。
R7 は `対応 Advisory` とし、Draft Security Advisory の GHSA ID を書く。
