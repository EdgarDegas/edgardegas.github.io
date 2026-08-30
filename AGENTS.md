# Article management

This repository is a Jekyll blog. Treat files in `_posts/` as the source of truth for published articles.

## Create an article

- Name posts `_posts/YYYY-MM-DD-slug.md`. The date controls ordering and `slug` becomes the public URL because `_config.yml` sets `permalink: /:slug.html`.
- Prefer a stable, readable ASCII slug. Do not rename a published post unless a URL change is intentional.
- `./start.sh <slug>` creates a post dated today with minimal front matter. Complete the front matter before publishing.
- Use this front matter shape:

  ```yaml
  ---
  layout: post
  title: Article title
  description: A concise summary used by feeds and search metadata
  locale: zh_Hans
  disc_url: https://github.com/EdgarDegas/edgardegas.github.io/discussions/NUMBER
  category: repo
  ---
  ```

  `layout` and `title` are required. Use `description` and `locale` for normal articles. `disc_url` and `category` are optional; omit them instead of leaving empty values. Quote YAML values when punctuation could be parsed as YAML syntax.

## Write and edit

- Preserve the article's language, tone, technical meaning, and Markdown style. Most current articles are Simplified Chinese technical essays.
- Follow the existing posts by using `#` for top-level article sections. Do not repeat the article title in the Markdown body; the post layout renders the front-matter title.
- Use fenced code blocks with a language identifier such as `swift`, `c`, or `text`.
- Link to another post with Jekyll's stable form: `{% post_url YYYY-MM-DD-slug %}`. Use ordinary Markdown links for external sources.
- For translations, retain clear source and author attribution near the beginning of the article.
- Do not modify unrelated prose while making a targeted correction. Avoid reformatting an entire article just to change a small passage.

## Images and other assets

- Put article-specific images in `_posts/YYYY-MM-DD-slug.assets/`, matching the post filename without `.md`.
- Reference them relatively from the article, for example:

  ```markdown
  ![Useful description](YYYY-MM-DD-slug.assets/example.png)
  ```

- Use descriptive alt text. Keep original-quality images when text or code must remain readable, and avoid adding large uncompressed files unnecessarily.
- When renaming or deleting an asset, update every reference. Delete an asset directory only after confirming no post uses it.

## Discussions

- A post with `disc_url` gets a “like or comment” link from `_layouts/post.html`.
- `start_discussion.sh` creates a real GitHub Discussion and writes its URL into the post. This is an external, user-visible action: run it only when explicitly requested and never commit or expose a GitHub token.
- Creating a Discussion is part of the normal publishing workflow unless the user explicitly opts out. A request to publish an article authorizes creating its Discussion.
- Set `GH_TOKEN` securely, then invoke `./start_discussion.sh ./_posts/YYYY-MM-DD-slug.md`. The script also accepts a token as its second argument for compatibility. The Docker wrapper is available when the `githubiocli` image is configured.
- The script is idempotent for posts that already have `disc_url`: it prints the existing URL without creating another Discussion.

## Publish an article

1. Complete and verify the post, including its intended publication date and optional category.
2. Unless the user opts out, load `GH_TOKEN` without printing it and run `./start_discussion.sh ./_posts/YYYY-MM-DD-slug.md` before committing.
3. Confirm that `disc_url` points to the newly created or existing GitHub Discussion.
4. Run the checks in “Verify changes” below.
5. Stage only the article, its assets, and directly related publishing changes. Review the staged diff before committing.
6. Push the intended branch, then verify that the public article URL responds successfully.

## Publishing behavior

- The home page automatically shows the five newest posts; `archive.md` automatically lists the full collection. Do not hand-edit either page when adding an ordinary article.
- Categories are optional. Use the established identifiers consistently:
  - `repo` for articles about the author's software repositories and projects.
  - `life` for everyday life, personal experiences, travel, food, hobbies, and reflections. Display it as “生活” in reader-facing navigation.
- Add a new category identifier only when existing categories do not fit and a category view or include will consume it.
- A future date may keep a post unpublished depending on the Jekyll/GitHub Pages build settings. Use the intended publication date, not merely the edit date.

## Verify changes

Before handing off article changes:

1. Check that front matter has matching opening and closing `---` lines and valid YAML.
2. Confirm internal `{% post_url ... %}` targets and local image paths exist.
3. Review the diff for accidental prose changes, secrets, editor files, or generated `_site/` output.
4. Run `bundle exec jekyll build` from the repository root. If dependencies are not installed, report that clearly rather than committing generated output.
5. For layout-sensitive edits, run `bundle exec jekyll serve` and inspect the article, code blocks, links, images, home page, and archive locally.

Do not commit `_site/`, `.jekyll-cache/`, credentials, or temporary preview files.
