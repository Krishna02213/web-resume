# Krishna Sen — portfolio

A responsive, static portfolio built from the supplied résumé. Plain HTML, CSS, and JavaScript; no backend, database, package install, build step, or external font/CDN dependency.

## Run with Nginx using Docker

Start Docker Desktop (or a Docker daemon), then run in this directory:

```sh
docker compose up -d --build
```

Open http://localhost:8080. Nginx serves the frontend directly.

Stop it with `docker compose down`.

## Use an existing Nginx installation

Copy `index.html`, `styles.css`, `script.js`, and the `assets` directory to your web root, for example `/var/www/krishna-portfolio`. Copy `nginx.conf` into your Nginx configuration directory, change its `root` to that web root, and change `server_name` to your domain. On Debian/Ubuntu, place it in `/etc/nginx/sites-available/krishna-portfolio` and enable it in `sites-enabled`. Replace the existing default site if it also listens on port 80 for the same hostname.

Validate and reload:

```sh
sudo nginx -t
sudo systemctl reload nginx
```

Add HTTPS through your hosting provider or preferred certificate setup for a public deployment.

## Local preview without Docker

```sh
python3 -m http.server 8080
```

Open http://localhost:8080. This command is only a development preview; production uses Nginx.

## Edit the website

- `index.html`: résumé content, projects, links, and contact details.
- `styles.css`: palette, typography, illustrations, and responsive layout.
- `script.js`: copy-email interaction, current year, and navigation highlights.
- `assets/krishna-sen-resume.pdf`: downloadable original résumé.
- `nginx.conf`: static server configuration.

Project artwork is illustrative, not screenshots of the linked applications. External project and certificate URLs come from the résumé. The contact links open the visitor’s email application; no form service is required.
