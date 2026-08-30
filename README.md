This is a repo that holds content for a blog.
[Open the blog here](https://edgardegas.github.io).

## Local preview with Docker

Build the image and start the Jekyll development server:

```shell
docker compose up --build
```

Open <http://localhost:4000>. Changes to posts, layouts, includes, Sass, and other site files are rebuilt automatically. LiveReload uses port `35729`.

Stop the preview with `Ctrl-C`, then remove the container:

```shell
docker compose down
```

Ruby gems are installed in the image. The Jekyll and Sass caches and generated `_site` directory are stored in Docker volumes instead of the repository. After changing `Gemfile` or `Gemfile.lock`, rebuild with:

```shell
docker compose build
docker compose up
```

Run a production-style build check without starting the preview server:

```shell
docker compose run --rm blog bundle exec jekyll build --config _config.yml,_config.docker.yml
```
