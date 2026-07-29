# OfficeWeave リリース手順

本書は、新しい版を公開する手順を定義する。

## 1. 版数の付け方

```text
0.y.z   互換性を保証しない段階。y の更新で機能の追加、z の更新で修正
1.0.0   実運用での利用を想定できると判断した時点で付ける
```

版数は `VERSION` を唯一の出所とする。
複数の場所へ書くと、更新し忘れた側が実態と食い違う。

## 2. 手順

### 変更履歴の更新

`CHANGELOG.md` へ、追加、変更、修正、制限を記載する。

利用者が読む文書として書く。内部の実装の言葉を持ち込まない。

### 版数の更新

```bash
echo "0.2.0" > VERSION
```

### 検証

開発用の構成で検証を通す。

```bash
docker compose exec web bin/verify
```

構成そのものの分離は、ホスト側で確かめる。

```bash
script/check_compose_isolation
```

配布用の構成でも起動を確認する。

```bash
docker compose -f compose.production.yaml up -d --build
```

```bash
docker compose -f compose.production.yaml exec web bin/diagnose
```

### 記録

```bash
git commit -am "chore: 0.2.0 を公開する"
```

```bash
git tag -a v0.2.0 -m "0.2.0"
```

```bash
git push origin main --tags
```

## 3. 公開の前に確認すること

```text
変更履歴が最新の内容と一致している
制限として残っている項目が記載されている
設定項目が増えた場合、.env.example と設定の文書へ反映されている
移行が必要な変更がある場合、アップグレードの手順へ注意点を追記している
検証がすべて成功している
配布用の構成でクリーンな環境から起動できる
```

## 4. 公開しないもの

- 実在する個人や組織の情報を含むデータ
- 接続情報と鍵
- 検証用の資格情報

配布用のイメージにはこれらを含めない。
`.dockerignore` で除外している。
