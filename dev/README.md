# Local Development Environment

Docker Compose setup for running Bank of Z locally. Starts a z/OS Connect Designer container alongside an nginx frontend.

## Prerequisites

- Docker Desktop (or compatible Docker runtime)
- Credentials and connection details for your z/OS environment

## Files

```
dev/
├── docker-compose.yaml       # Compose services: zosConnect + frontend
├── nginx.frontend.conf       # nginx reverse-proxy config for the frontend
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

## How API URL routing works

```
Browser → localhost:3001/api/customers/1234
         ↓ nginx proxy_pass (URI unchanged)
         zosConnect:9080/api/customers/1234   ← zosConnect serves at /api/*
```

[`nginx.frontend.conf`](nginx.frontend.conf) proxies all `/api/` requests to the `zosConnect` container on port 9080, **keeping the `/api` prefix** (no trailing slash on `proxy_pass`). `config.js` uses the relative path `/api` as the base URL when served from port 3001.

### Designer "Test API" button

The z/OS Connect Designer uses the `servers.url` field from the OpenAPI spec to build test request URLs. With `servers: [{url: /api}]`, clicking "Test API" sends requests to `https://localhost:9443/api/customers/1234`, which matches where zosConnect serves the API.

### Production (Liberty, port 9081)

`config.js` detects port 9081 and constructs an absolute URL (`http://<hostname>:9080/api`), bypassing nginx entirely. No changes needed for production deployments.
