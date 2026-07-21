# H3N automation

## Setup

1. Copy the environment template and fill in your credentials:
   ```bash
   cp .env.template .env
   ```

2. Edit `.env` and replace the placeholder values with your actual credentials:
   - `PAT`: Your GitHub Enterprise PAT
   - `H3N_USER`: Your W3 email
   - `H3N_PASS`: Your W3 password
   - `ARTIFACTORY_USER`: Your W3 email
   - `ARTIFACTORY_API_KEY`: Your Artifactory API key
   - `TWYD_H3N_SYS_NAME`: Your H3N system name

**Note:** The `.env` file is gitignored to protect your credentials.

## Start container

### Using Docker Compose (Recommended)

```bash
cd h3n
docker-compose up -d
docker exec -it h3n-provisioning bash
```

To stop the container:
```bash
docker-compose down
```

### Using Docker Run (Legacy)

```bash
docker run \
  --name H3N-provisioning \
  -v $(pwd)/h3n:/root/h3n \
  -v ~/.ssh/id_rsa:/root/.ssh/id_rsa:ro \
  -v ~/.ssh/id_rsa.pub:/root/.ssh/id_rsa.pub:ro \
  -it \
  icr.io/continuous-delivery/pipeline/pipeline-base-ubi:3.81 \
  bash
```
poo poo poo poo poo pooo!!!!!