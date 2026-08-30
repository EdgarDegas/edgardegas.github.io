FROM ruby:3.1-slim-bookworm

ENV BUNDLE_JOBS=4 \
    BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_RETRY=3 \
    JEKYLL_ENV=development

RUN apt-get update \
    && apt-get install --yes --no-install-recommends build-essential git \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /srv/jekyll

COPY Gemfile Gemfile.lock no-style-please.gemspec ./
RUN bundle install

COPY . .

EXPOSE 4000 35729

CMD ["bundle", "exec", "jekyll", "serve", "--config", "_config.yml,_config.docker.yml", "--host", "0.0.0.0", "--port", "4000", "--livereload", "--force_polling"]
