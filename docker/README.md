# Docker — short practice notes

Docker packages an application and its dependencies into an **image**. A **container** is a running instance of that image. Our container runs Nginx to serve HTML, CSS, JavaScript, and assets; no backend or database is required.

## Files and their purpose

| File | Meaning |
| --- | --- |
| `Dockerfile` | Instructions to build the image. |
| `nginx.conf` | Tells Nginx how to serve the website on port 80. |
| `.dockerignore` | Excludes unnecessary files from the build context. |
| `compose.yaml` | Defines the build, ports, and restart policy in one file. |
| `index.html`, `styles.css`, `script.js`, `assets/` | Website content, appearance, behaviour, and downloads. |

## Our Dockerfile

```dockerfile
FROM nginx:stable-alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY index.html styles.css script.js /usr/share/nginx/html/
COPY assets/ /usr/share/nginx/html/assets/
EXPOSE 80
```

- `FROM`: starts with an image containing Nginx on Alpine Linux.
- `COPY`: copies configuration and website files into the image.
- `EXPOSE 80`: documents the container port; `-p` publishes it on the host.
- Nginx's base image already supplies the startup command, so no extra `CMD` is needed here.

## Build, test, and run

On the Mac, run from `WEB_RESUME/docker`. On EC2, run from the directory containing the uploaded Dockerfile and website files. Use `sudo docker` on EC2 if required by permissions.

```bash
docker build -t portfolio:1.0 .
docker run --rm portfolio:1.0 nginx -t
docker run -d --name portfolio --restart unless-stopped -p 80:80 portfolio:1.0
curl -I http://localhost
```

| Part | Meaning |
| --- | --- |
| `build -t portfolio:1.0 .` | Builds and tags an image using the current directory as the build context. |
| `nginx -t` / `--rm` | Checks Nginx configuration / removes the temporary test container. |
| `-d` / `--name portfolio` | Runs in the background / assigns a container name. |
| `--restart unless-stopped` | Restarts the container automatically unless deliberately stopped. |
| `-p 80:80` | Connects host port 80 to container port 80. |
| `curl -I` | Checks HTTP response headers; `200 OK` indicates a successful response. |

For public EC2 access, allow HTTP port 80 in its security group and open `http://EC2_PUBLIC_IP`. SSH port 22 is used for administration and deployment.

## Useful commands

| Command | Purpose |
| --- | --- |
| `docker ps` / `docker ps -a` | Lists running containers / all containers. |
| `docker images` | Lists local images. |
| `docker logs portfolio` | Shows container logs. |
| `docker stop portfolio` | Stops the container. |
| `docker rm portfolio` | Removes the stopped container; keeps its image. |

## Make a website change

Edit the source files, then rebuild and replace the container:

```bash
docker build -t portfolio:v2 .
docker stop portfolio
docker rm portfolio
docker run -d --name portfolio --restart unless-stopped -p 80:80 portfolio:v2
```

`COPY` puts files into the image at build time, so editing the source requires a new image and container. This manual replacement briefly interrupts the website.

## Docker Compose on the Mac

```bash
docker compose up -d --build
docker compose down
```

The first command builds and starts the website at `http://localhost:8080` using our Compose port mapping `8080:80`. The second removes its containers and network. Docker Desktop must be running.

## Our GitHub Actions pipeline

Push to `main` → GitHub-hosted runner builds the image → validates Nginx and tests the website → transfers the tested image over SSH → replaces the EC2 container → checks the public website. Pull requests build and test only.

`EC2_SSH_KEY` is stored in GitHub Actions secrets. The workflow retains a previous container for rollback. After moving source files into `docker/`, its build step must use that directory as the build context, for example `docker build -t "$IMAGE" ./docker`.
