# 開発用のアプリケーションコンテナ。
# 配布用の構成は P12 で別途用意する。
ARG RUBY_VERSION=3.4.10
FROM ruby:${RUBY_VERSION}-slim-bookworm

# データベースと同じ系列のクライアントを入れる。
# 基盤の既定に含まれる版はデータベースより古く、
# スキーマ定義の書き出しやバックアップの取得が版の不一致で失敗する。
ARG POSTGRESQL_MAJOR_VERSION=18

# build-essential と libpq-dev は pg gem のネイティブ拡張ビルドに必要。
# postgresql-client は bin/rails dbconsole、スキーマ定義の書き出し、接続確認に必要。
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      gnupg && \
    install -d /usr/share/postgresql-common/pgdg && \
    curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc \
      -o /usr/share/postgresql-common/pgdg/apt.postgresql.org.asc && \
    echo "deb [signed-by=/usr/share/postgresql-common/pgdg/apt.postgresql.org.asc]" \
      "https://apt.postgresql.org/pub/repos/apt bookworm-pgdg main" \
      > /etc/apt/sources.list.d/pgdg.list && \
    apt-get update -qq && \
    apt-get install -y --no-install-recommends \
      build-essential \
      git \
      libpq-dev \
      libyaml-dev \
      pkg-config \
      postgresql-client-${POSTGRESQL_MAJOR_VERSION} && \
    rm -rf /var/lib/apt/lists/*

ENV LANG=C.UTF-8 \
    BUNDLE_PATH=/usr/local/bundle

WORKDIR /app

# 依存定義だけを先に取り込み、アプリケーションコードの変更で
# bundle install が再実行されないようにする。
COPY Gemfile Gemfile.lock ./

# 依存を解決する道具は、Gemfile.lock が記録している版を入れる。
# 基盤のイメージに含まれる版に任せると、それが変わったときに、
# 依存の解決だけが黙って別の道具へ移る。
# 版をここへ書き写さないのは、lock を上げたときに片方だけが古いまま残るため。
RUN gem install bundler --no-document \
      -v "$(sed -n '/^BUNDLED WITH$/{n;s/[[:space:]]//g;p;}' Gemfile.lock)"

RUN bundle install

# ソースコードは写さない。compose がホストの内容を /app へ重ねるため、
# 写しても実行時には必ず覆われる。
#
# 写すと、書き換えのたびに新しい層ができ、前のイメージが参照されないまま
# 残る。捨てられると分かっているものを、組み立てのたびに作ることになる。
#
# このイメージは、ホストの作業ディレクトリを /app へ重ねて使う。
# 重ねずに起動すると、/app が空のため bin/docker-entrypoint を見つけられない。

EXPOSE 3000

ENTRYPOINT ["bin/docker-entrypoint"]
CMD ["bin/rails", "server", "-b", "0.0.0.0", "-p", "3000"]
