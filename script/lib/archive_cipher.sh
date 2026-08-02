# 書庫の暗号化で、取得する側と復元する側が共有する取り決め。
#
# このファイルは実行しない。script/production_backup と
# script/production_restore が読み込む。
#
# 書庫へ入るのは塩だけである。要約関数と反復回数は書庫へ残らないため、
# 取得と復元で同じ値を使わなければ復号できない。2 か所へ書き写さず、
# ここだけに置く。
#
# 形式は openssl enc の標準の形とする。復元の手段を、この製品が
# 手元にあることに依存させない。書庫だけが残った状況でも、openssl が
# あれば中身を取り出せる。
#
#   openssl enc -d -aes-256-cbc -md sha256 -pbkdf2 -iter 600000 \
#     -pass file:<パスフレーズのファイル> -in <書庫> | tar --extract --gzip
#
# 改ざんの検知は行わない。openssl enc は認証付きの方式を扱えず、
# 独自に MAC を足すと、上の 1 行で取り出せる形から外れる。
# 秘匿は暗号化で、改ざんへの備えは保管先の権限で行う。

# 取得と復元で必ず同じものを使う。
ARCHIVE_CIPHER_ARGUMENTS="-aes-256-cbc -md sha256 -pbkdf2 -iter 600000 -salt"

# openssl が -salt を付けて書き出す先頭 8 バイト。
ARCHIVE_CIPHER_MAGIC="Salted__"

# 書庫が暗号化されているかを、名前ではなく中身で判定する。
#
# 名前で判断すると、改名した書庫や、拡張子を落として転送された書庫を
# 平文として扱う。そこで待っているのは、暗号のまま復元を試みることである。
archive_cipher_encrypted() {
  [ "$(head -c 8 "$1" 2>/dev/null)" = "${ARCHIVE_CIPHER_MAGIC}" ]
}

# パスフレーズのファイルを、破壊的な操作を始める前に検査する。
#
# 値そのものは変数へ入れない。読み取れること、1 行目が空でないことだけを見る。
# openssl は -pass file: で 1 行目だけを使う。空の 1 行目を渡すと、
# 空のパスフレーズで暗号化された書庫ができる。
archive_cipher_check_passphrase_file() {
  local path="$1"

  if [ ! -f "${path}" ]; then
    echo "パスフレーズのファイルが見つかりません: ${path}" >&2
    return 1
  fi

  if [ ! -r "${path}" ]; then
    echo "パスフレーズのファイルを読み取れません: ${path}" >&2
    return 1
  fi

  if ! awk 'NR == 1 { exit length($0) == 0 } END { if (NR == 0) exit 1 }' "${path}"; then
    echo "パスフレーズのファイルの 1 行目が空です: ${path}" >&2
    return 1
  fi

  if ! command -v openssl >/dev/null 2>&1; then
    echo "openssl が見つかりません。書庫の暗号化には openssl が必要です。" >&2
    return 1
  fi
}
