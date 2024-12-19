# Docker CA

Docker Container using Nix that uses a custom CA chain.

## Tasks

### gomod2nix-update

```bash
gomod2nix
```

### build

```bash
nix build
```

### run

```bash
nix run
```

### develop

```bash
nix develop
```

### docker-build

```bash
nix build .#docker-image
```

### docker-load

Once you've built the image, you can load it into a local Docker daemon with `docker load`.

```bash
docker load < result
```

### docker-run

interactive: true

Check that you can access CA certificate sites, e.g. `https://google.com`, plus the local server at `https://localhost:8443`.

```bash
docker run -it --rm --net=host app:latest
```

### serve

This will serve a the current directory over HTTPS. The CA of `ca-chain.cert.pem` wont be trusted automatically, it will need to be merged with the system CA store.

```bash
serve -crt="localhost.cert.pem" -key="localhost.key.pem" -dir=www -addr=0.0.0.0:8443
```
