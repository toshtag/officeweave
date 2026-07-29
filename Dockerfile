# 開発用のアプリケーションコンテナ。
# 配布用の構成は P12 で別途用意する。
ARG RUBY_VERSION=3.4.10
FROM ruby:${RUBY_VERSION}-slim-bookworm

# build-essential と libpq-dev は pg gem のネイティブ拡張ビルドに必要。
# postgresql-client は bin/rails dbconsole と接続確認に必要。
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
      build-essential \
      curl \
      git \
      libpq-dev \
      libyaml-dev \
      pkg-config \
      postgresql-client && \
    rm -rf /var/lib/apt/lists/*

ENV LANG=C.UTF-8 \
    BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_JOBS=4

WORKDIR /app

# 依存定義だけを先に取り込み、アプリケーションコードの変更で
# bundle install が再実行されないようにする。
COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .

EXPOSE 3000

CMD ["bin/rails", "server", "-b", "0.0.0.0", "-p", "3000"]
