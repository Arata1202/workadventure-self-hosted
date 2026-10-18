# WorkAdventure Self-Hosted

A community-maintained self-hosting setup for [WorkAdventure](https://workadventu.re) using Docker Compose and Terraform.

This project is not affiliated with or endorsed by the WorkAdventure core team. WorkAdventure is developed by [TheCodingMachine](https://www.thecodingmachine.com/). See the [upstream repository](https://github.com/workadventure/workadventure) for the official source code and documentation.

<div align="right">

![GitHub License](https://img.shields.io/github/license/Arata1202/workadventure-self-hosted)

</div>

## Getting Started

- This guide supports both AWS EC2 and Azure VM with Terraform.

### Prepare Local Repository

```bash
# Local

# Clone repository
git clone https://github.com/Arata1202/workadventure-self-hosted.git
cd workadventure-self-hosted

# Install dependencies
make wa-init
```

### Create Resources with Terraform

When using Azure, generate an SSH key first:

```bash
# Local

ssh-keygen -t ed25519 -C "workadventure" -f ~/.ssh/workadventure -N ""
```

```bash
# Local

# Move to repository
cd workadventure-self-hosted
cd terraform/aws # or terraform/azure

# Prepare and edit local values
cp terraform.tfvars.example terraform.tfvars
vi terraform.tfvars

# Create resources
terraform init
terraform plan
terraform apply
```

For Azure, set `ssh_public_key` in `terraform.tfvars` to the contents of `~/.ssh/workadventure.pub`.

### Connect AWS EC2 with SSM

- Default for AWS is SSM.

```bash
# Local

# Configure AWS CLI credentials and region before connecting
aws configure

# Connect to AWS EC2 via SSM
aws ssm start-session --target <EC2_INSTANCE_ID>

# Switch to ubuntu user
sudo -iu ubuntu
```

### Configure SSH Access

- Default for Azure is SSH (Azure Bastion can be costly).

```sshconfig
Host workadventure
  HostName <VM_PUBLIC_IPV4_ADDRESS>
  User ubuntu
  IdentityFile ~/.ssh/workadventure
```

```bash
# Local

# Connect to VM via SSH
ssh workadventure
```

### Prepare VM Repository

```bash
# VM

# Clone repository
git clone https://github.com/Arata1202/workadventure-self-hosted.git
cd workadventure-self-hosted

# Set up Ubuntu
./ubuntu/setup.sh

# Install dependencies
make wa-init
```

### Set Up WorkAdventure Server

- https://github.com/workadventure/workadventure/blob/develop/contrib/docker/README.md
- https://github.com/workadventure/workadventure/releases

```bash
# VM

# Move to repository
cd workadventure-self-hosted

# Remove existing .env file
rm -f .env

# Generate random strings for .env values
openssl rand -hex 16
openssl rand -hex 32

# Prepare and edit .env file
cp .env.example .env
vi .env
```

```env
# Required
SECRET_KEY=<UNIQUE_RANDOM_64_HEX>
DOMAIN=<YOUR_FQDN>
MAP_STORAGE_AUTHENTICATION_TOKEN=<UNIQUE_RANDOM_64_HEX>
MAP_STORAGE_AUTHENTICATION_USER=admin
MAP_STORAGE_AUTHENTICATION_PASSWORD=<UNIQUE_RANDOM_32_HEX>
```

1. Add an A record in your DNS provider to point your domain to the VM public IP

| Record Name | Type | Value                    | TTL |
| ----------- | ---- | ------------------------ | --- |
| <YOUR_FQDN> | A    | <VM_PUBLIC_IPV4_ADDRESS> | 300 |

```bash
# VM

# Move to repository
cd workadventure-self-hosted

# Encrypt .env file
make encrypt

# Start services
make up
```

Back up `.env.keys` securely. It is required to decrypt `.env` and must not be committed.

### Update Configuration

```bash
# VM

# Move to repository
cd workadventure-self-hosted

# Edit .env file
make decrypt
vi .env
make encrypt

# Restart server
make up-f
```

```env
# Required
TZ=Asia/Tokyo

# Optional
ACME_EMAIL=<EMAIL_ADDRESS>
ENABLE_TELEMETRY=true
SECURITY_EMAIL=<EMAIL_ADDRESS>
FEATURE_FLAG_BROADCAST_AREAS=true
```

### Upload a Map Edited with Tiled

- https://docs.workadventu.re/map-building/tiled-editor/publish/wa-hosted

```bash
# Local

# Move to repository
cd workadventure-self-hosted

# Prepare .env file
cp maps/.env.example maps/.env

# Preview the map locally
make wa-dev

# Edit the map file (maps/office.tmj) using Tiled

# Upload the map
make wa-upload

Please enter your Map storage URL: https://<YOUR_FQDN>/map-storage/
Please enter your API Key: <MAP_STORAGE_AUTHENTICATION_TOKEN>
Upload directory: maps
```

```bash
# VM

# Move to repository
cd workadventure-self-hosted

# Edit .env file
make decrypt
vi .env
make encrypt

# Restart server
make up-f
```

```env
# Required
START_ROOM_URL=/~/maps/office.wam
MAP_STORAGE_ENABLE_BEARER_AUTHENTICATION=true
```

1. Access the uploaded map
   `https://<YOUR_FQDN>`

### Set Up GitHub Actions

1. Configure GitHub Actions secrets for `upload-wa-maps.yml`

```env
# Required
UPLOAD_MODE=MAP_STORAGE
MAP_STORAGE_URL=https://<YOUR_FQDN>/map-storage/
MAP_STORAGE_API_KEY=<MAP_STORAGE_AUTHENTICATION_TOKEN>
UPLOAD_DIRECTORY=maps
```

2. Configure GitHub Actions secrets for `deploy.yml`

> [!NOTE]
> The `deploy.yml` workflow requires direct SSH access and is not compatible with the default AWS SSM setup.

```env
# Required
SSH_HOST=<VM_PUBLIC_IPV4_ADDRESS>
SSH_USERNAME=ubuntu
SSH_PRIVATE_KEY=<SSH_PRIVATE_KEY>
```

3. Run the `deploy` workflow manually from GitHub Actions to apply repository changes to the VM

### Set Up Presence Notifications

The [WorkAdventure Presence Notifier](https://github.com/Arata1202/workadventure-presence-notifier) sends periodic snapshots of the users who are currently online to Slack. The `presence` service connects to the internal `back:50051` gRPC endpoint and does not expose an additional host port.

The service is part of the default Compose stack. Configure `SLACK_WEBHOOK_URL` before running `make up-f`; the notifier exits when the webhook is missing and the configured restart policy will restart it.

1. Store the Slack Incoming Webhook URL in the encrypted environment file.

```bash
make decrypt
# Add SLACK_WEBHOOK_URL=https://hooks.slack.com/services/...
make encrypt
```

The commands below run Compose through dotenvx. The decrypted value is injected into the process environment and forwarded to the container without being stored in `docker-compose.yaml`.

2. Send one immediate test notification. This command sends a real Slack message and removes the temporary container when it exits.

```bash
npx dotenvx run -- docker compose run --rm presence \
  --config /etc/presence/config.yaml \
  --once
```

3. Start the notifier in daemon mode after the one-shot check succeeds.

```bash
npx dotenvx run -- docker compose up -d --build presence
```

Normal daemon mode waits for the configured interval before sending its first notification. Edit `presence/config.yaml` to change the interval or message templates.

Inspect logs or remove the notifier:

```bash
npx dotenvx run -- docker compose logs -f presence
npx dotenvx run -- docker compose rm -f -s presence
```

The notifier sends WorkAdventure display names to the configured Slack workspace. It does not store presence history, IP addresses, coordinates, authentication claims, or tokens. Restrict access to the Slack channel and do not expose the internal gRPC port publicly.

### Set Up Microsoft Entra ID OIDC

For Google OIDC, see [Set Up Google OIDC](docs/google-oidc.md).

1. Access Microsoft Azure portal
2. Go to Microsoft Entra ID -> App registrations
3. Create a new registration
   - Name: WorkAdventure
   - Supported account types: Accounts in this organizational directory only
   - Platform: Web
   - Redirect URI: `https://<YOUR_FQDN>/openid-callback`
4. Open Authentication and add another Web redirect URI
   - Redirect URI: `https://matrix.<YOUR_FQDN>/_synapse/client/oidc/callback`
5. Open Certificates & secrets and create a new client secret
6. Open Token configuration and add the `email` optional claim
   - Token type: ID
   - Claim: `email`
   - Keep `Turn on the Microsoft Graph email permission` enabled
7. Save the following values
   - Application (client) ID
   - Directory (tenant) ID
   - Client secret Value (not the Secret ID)

```bash
# VM

# Move to repository
cd workadventure-self-hosted

# Edit .env file
make decrypt
vi .env
make encrypt

# Restart server
make up-f
```

```env
# Required
OPENID_IDP_ID=microsoft
OPENID_IDP_NAME=Microsoft
OPENID_CLIENT_ID=<APPLICATION_CLIENT_ID>
OPENID_CLIENT_SECRET=<CLIENT_SECRET_VALUE>
OPENID_CLIENT_ISSUER=https://login.microsoftonline.com/<DIRECTORY_TENANT_ID>/v2.0
OPENID_LOGOUT_REDIRECT_URL=https://<YOUR_FQDN>
OPENID_USERNAME_CLAIM=preferred_username
OPENID_SCOPE=openid email profile

# Optional
DISABLE_ANONYMOUS=true
```

### Set Up LiveKit

```bash
# VM

# Move to repository
cd workadventure-self-hosted

# Generate random strings for .env values
openssl rand -hex 32

# Edit .env file
make decrypt
vi .env
make encrypt

# Restart server
make up-f
```

```env
# Required
LIVEKIT_HOST=https://livekit.<YOUR_FQDN>
LIVEKIT_API_KEY=<UNIQUE_RANDOM_64_HEX>
LIVEKIT_API_SECRET=<UNIQUE_RANDOM_64_HEX>

# Optional
MAX_PER_GROUP=<NUMBER>
```

1. Add an A record in your DNS provider to point your domain to the VM public IP

| Record Name         | Type | Value                    | TTL |
| ------------------- | ---- | ------------------------ | --- |
| livekit.<YOUR_FQDN> | A    | <VM_PUBLIC_IPV4_ADDRESS> | 300 |

### Set Up Coturn

```bash
# VM

# Move to repository
cd workadventure-self-hosted

# Generate random strings for .env values
openssl rand -hex 32

# Edit .env file
make decrypt
vi .env
make encrypt

# Restart server
make up-f
```

```env
# Required
TURN_SERVER=turn:<YOUR_FQDN>:3478,turns:<YOUR_FQDN>:5349
TURN_STATIC_AUTH_SECRET=<UNIQUE_RANDOM_64_HEX>
STUN_SERVER=stun:stun.l.google.com:19302
```

### Set Up Matrix

```bash
# VM

# Move to repository
cd workadventure-self-hosted

# Generate random strings for .env values
openssl rand -hex 16
openssl rand -hex 32

# Edit .env file
make decrypt
vi .env
make encrypt

# Prepare Synapse data volume
npx dotenvx run -- docker compose run --rm --user root --entrypoint sh synapse -lc 'chown -R 991:991 /data'

# Restart server
make up-f

# Create a Matrix Admin User
npx dotenvx run -- sh -lc 'docker compose exec synapse register_new_matrix_user -c /data/homeserver.yaml -u "$MATRIX_ADMIN_USER" -p "$MATRIX_ADMIN_PASSWORD" --admin http://localhost:8008'
```

```env
# Required
MATRIX_API_URI=http://synapse:8008/
MATRIX_DOMAIN=matrix.<YOUR_FQDN>
MATRIX_PUBLIC_URI=https://matrix.<YOUR_FQDN>
MATRIX_ADMIN_USER=admin
MATRIX_ADMIN_PASSWORD=<UNIQUE_RANDOM_32_HEX>
MATRIX_REGISTRATION_SHARED_SECRET=<UNIQUE_RANDOM_64_HEX>
MATRIX_MACAROON_SECRET_KEY=<UNIQUE_RANDOM_64_HEX>
MATRIX_FORM_SECRET=<UNIQUE_RANDOM_64_HEX>
POSTGRES_DB=synapse
POSTGRES_USER=admin
POSTGRES_PASSWORD=<UNIQUE_RANDOM_32_HEX>
```

1. Add an A record in your DNS provider to point your domain to the VM public IP

| Record Name        | Type | Value                    | TTL |
| ------------------ | ---- | ------------------------ | --- |
| matrix.<YOUR_FQDN> | A    | <VM_PUBLIC_IPV4_ADDRESS> | 300 |

### Log in to Matrix using Element

1. Access Element Web: `https://element.io`
2. Click Sign in -> Open Element web
3. Click Sign in
4. Enter your Matrix homeserver URL: `https://matrix.<YOUR_FQDN>`
5. Click Continue
6. Enter your Matrix credentials:
   - Username: admin
   - Password: <MATRIX_ADMIN_PASSWORD>
7. Click Sign in
8. After successful authentication, you will be redirected back to Element and logged in

### Set Up Egress with RustFS

```bash
# VM

# Move to repository
cd workadventure-self-hosted

# Generate random strings for .env values
openssl rand -hex 32

# Edit .env file
make decrypt
vi .env
make encrypt

# Restart server
make up-f
```

```env
# Required
LIVEKIT_RECORDING_S3_ENDPOINT=http://rustfs-livekit:9000
LIVEKIT_RECORDING_S3_CDN_ENDPOINT=https://cdn-livekit.<YOUR_FQDN>
LIVEKIT_RECORDING_S3_ACCESS_KEY=<UNIQUE_RANDOM_64_HEX>
LIVEKIT_RECORDING_S3_SECRET_KEY=<UNIQUE_RANDOM_64_HEX>
LIVEKIT_RECORDING_S3_BUCKET=livekit-recordings
LIVEKIT_RECORDING_S3_REGION=ap-northeast-1
MAX_USERS_FOR_WEBRTC=0
```

1. Add A records in your DNS provider to point your domain to the VM public IP

| Record Name                | Type | Value                    | TTL |
| -------------------------- | ---- | ------------------------ | --- |
| cdn-livekit.<YOUR_FQDN>    | A    | <VM_PUBLIC_IPV4_ADDRESS> | 300 |
| rustfs-livekit.<YOUR_FQDN> | A    | <VM_PUBLIC_IPV4_ADDRESS> | 300 |

### Log in to RustFS

1. Access RustFS Console: `https://rustfs-livekit.<YOUR_FQDN>`
2. Enter your RustFS credentials:
   - Username: <LIVEKIT_RECORDING_S3_ACCESS_KEY>
   - Password: <LIVEKIT_RECORDING_S3_SECRET_KEY>
3. Click Sign in
4. After successful authentication, you will be logged in
