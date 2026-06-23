# Local Development Environment

Docker Compose setup for running Bank of Z locally. Starts a z/OS Connect Designer container alongside an nginx frontend.

## Prerequisites

- Docker Desktop (or compatible Docker runtime)
- Credentials and connection details for your z/OS environment

## Files

```
dev/
├── docker-compose.yaml       # Compose services: zosConnect + frontend
├── nginx.frontend.conf       # nginx config template (API_BASE_URL injected at startup)
└── README.md                 # This file
```

## Starting the stack

```bash
cd dev
docker compose up
```

- Frontend: http://localhost:3001
- z/OS Connect: http://localhost:9080 / https://localhost:9443

## Configuration

### z/OS Connect

Set your z/OS connection details in `docker-compose.yaml` (or via a `.env` file in the `dev/` folder):

```
CICS_USER=
CICS_PASSWORD=
CICS_HOST=
CICS_PORT=
IMS_USER=
IMS_PASSWORD=
IMS_HOST=
IMS_PORT=
IMS_DATASTORE=
```

### API Base URL

The frontend nginx container rewrites `config.js` at startup to point at the backend. The default in `docker-compose.yaml` is:

```
API_BASE_URL=http://zosConnect:9080
```

Override it in a `dev/.env` file to point at a different backend:

```
API_BASE_URL=https://my-zosconnect-host:9080
```

## How API URL injection works

[`nginx.frontend.conf`](nginx.frontend.conf) is mounted as an nginx template. The `nginx:alpine` entrypoint runs `envsubst` on all files in `/etc/nginx/templates/` before starting nginx, substituting `${API_BASE_URL}` with the environment variable value.

The nginx `sub_filter` directive then rewrites the `baseUrl` value in `config.js` responses on the fly:

```nginx
sub_filter "baseUrl: '/api'" "baseUrl: '${API_BASE_URL}'";
```

This means `src/frontend/config.js` is never modified — the substitution happens at the HTTP response layer. When the frontend is deployed to Liberty (WAR), nginx is not involved and `config.js` is served unchanged with `baseUrl: '/api'`.
