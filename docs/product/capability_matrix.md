# OfficeWeave 機能到達度

機能ごとの段階と到達度の**正本は [機能到達度の一覧](capability_registry.yml)** である。
本書は、その読み方だけを持つ。

同じ内容を散文と機械が読む形で二重に持たない。持つと、片方だけを直した
変更が必ず出る。実際に出た。散文が「条件 2 は満たす」と書き、一覧が
`unmet` を持つ状態が残っていた。

段階の決め方は [製品範囲](product_scope.md)、状態と条件は [受入条件](acceptance_criteria.md) にある。

## 1. いまの到達度を見る

一覧をそのまま読む。件数は数えれば出る。

```bash
docker compose exec web bin/rails runner '
  d = YAML.load_file("docs/product/capability_registry.yml")
  d["capabilities"].group_by { |c| [ c["stage"], c["state"] ] }.each { |k, v| puts "#{k.inspect} #{v.size}" }'
```

特定の機能を見る場合は、識別子で引く。

```bash
docker compose exec web bin/rails runner '
  d = YAML.load_file("docs/product/capability_registry.yml")
  puts d["capabilities"].find { |c| c["id"] == "core.authentication" }.to_yaml'
```

いつ時点の到達度かは、一覧の Git の履歴から特定する。
commit へ結び付けた証拠は、PR の本文と [版ごとの検証の記録](../releases/) が持つ。

## 2. 種類

```text
capability          利用者、管理者、運用者が使う機能
cross_cutting_gate  特定の機能に属さない横断の品質
release_gate        版全体の検証
```

段階（`stage`）を持つのは `capability` だけである。
`cross_cutting_gate` と `release_gate` は特定の段階に属さない。

## 3. 段階

```text
core      この製品が製品であるために要る機能        capabilities
suite     採用済みだが、この段階では実装しない拡張   suite_capabilities
extended  採否を決めていない領域                  extended_areas
（なし）   範囲外。製品ビジョンの非目標と対応する     out_of_scope
```

範囲外は第 4 の段階ではない。段階を持たない、という意味である。

右の列は、一覧のどのキーが持つかである。`core` だけが実装と検証と条件の
判定を持ち、残りは識別と、その段階に置いた理由だけを持つ。実装を始めて
いないものに、実装の位置と検証を書く欄は要らない。

## 4. 状態

```text
planned   決めたが、着手していない
partial   入口または実装はあるが、受入条件に未達の項目が残る
complete  受入条件をすべて満たし、証拠が揃う
deferred  採用を見送った
rejected  製品の範囲に入れない
```

段階ごとに取り得る状態は [受入条件](acceptance_criteria.md) の
「2.1 段階と状態の組合せ」が定める。

## 5. 機能が持つ項目

```yaml
id             識別子
name           名前
state          上の 5 つのいずれか
stage          上の 4 つのいずれか（範囲外は持たない）
entries        画面と API の入口。持たない機能は運用の入口や定期実行
implementation その機能を成立させる実装の位置。model に限らない
tests          その機能の退行を止めるテスト
docs           操作の手順を読める文書
criteria        共通条件ごとの判定
other_findings 共通条件に属さない、確認済みの未達
issue          担当したキャンペーン
dependencies   先に済んでいる必要のあるもの
```

`cross_cutting_gate` も同じ形を持つ。`stage` だけを持たない。

## 6. 条件ごとの判定

`criteria` は、[受入条件](acceptance_criteria.md) の
「5. Core に共通の受入条件」と同じ並びで、条件ごとに判定と理由を持つ。

```text
met             満たす
unmet           満たしていない
not_applicable  その機能には該当しない
not_assessed    まだ評価していない
```

`complete` は、条件がすべて `met` か `not_applicable` であり、
`other_findings` が空であることを求める。`not_assessed` が 1 つでも
残っていれば `complete` にできない。この関係は
`test/configuration/completion_registry_test.rb` が確かめる。

`partial` の判定は、そのとき実測またはコードの確認から判明したものである。
未評価の条件と、評価して満たしていた条件は、`not_assessed` で区別する。

## 7. 版の判定

本番準備済みかどうかは、機能ではなく**版**に対して判定する。
機能がすべて `complete` になっても、版の判定は別に行う。

判定は `release_gates` の `evaluations` が持ち、根拠となる実測は
[版ごとの検証の記録](../releases/) が持つ。一覧は記録を指すだけで、
実測の値そのものを写さない。写すと、片方だけが古くなる。

版の判定に必要な証拠と、`passed` と書ける条件は
[受入条件](acceptance_criteria.md) の「4. 実装済みと本番準備済み」が定める。

## 8. 入口の網羅

`config/routes.rb` にあるすべての経路が、いずれかの機能へ属する。

`bin/`、`script/`、`config/recurring.yml` にあるものは、
[製品範囲](product_scope.md) の 3 分類のいずれかへ属する。
製品の入口であれば機能へ、開発と検証の道具または内部の実行であれば、
その理由とともに対象の外とする。

入口を足したときは、属する機能を同じ変更で決める。
属する機能が無い入口は、機能を先に決めるまで足さない。
