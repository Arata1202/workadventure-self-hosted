# Contributing

Contributions are welcome. Please keep changes focused, documented, and safe for public self-hosted WorkAdventure deployments.

## Project scope

This repository maintains community deployment configuration for WorkAdventure, including Docker Compose, Terraform, maps, and deployment automation. It is not the upstream WorkAdventure application repository.

- Report issues in this repository when they concern its deployment configuration or documentation.
- Report WorkAdventure product bugs and feature requests to the [upstream WorkAdventure repository](https://github.com/workadventure/workadventure).
- Search existing issues and pull requests before opening a new one.
- Open an issue before large infrastructure changes or changes that affect existing deployments.
- Report vulnerabilities privately according to [SECURITY.md](SECURITY.md).
- Use English for repository documentation, issues, pull requests, commit messages, and configuration examples.

## Development setup

Requirements depend on the area being changed:

- Docker with Docker Compose
- Node.js and npm
- Terraform for infrastructure changes
- AWS CLI or Azure CLI only when validating the corresponding deployment

Clone the repository and install dependencies:

~~~sh
git clone https://github.com/Arata1202/workadventure-self-hosted.git
cd workadventure-self-hosted
make wa-init
~~~

## Secrets and deployment data

Never commit or publish:

- Decrypted environment values or the dotenvx private key
- Webhook URLs, access tokens, passwords, API keys, or cloud credentials
- Terraform state or non-example `terraform.tfvars` files
- SSH private keys
- Production hostnames, IP addresses, tenant IDs, resource IDs, or user data

Keep `.env` values encrypted with dotenvx. The `.env.keys` file must remain untracked and private. Use placeholders such as `example.com`, `<TOKEN>`, and `<RESOURCE_ID>` in documentation and reports.

## Validation

Run the checks that apply to your change.

Validate Docker Compose syntax without decrypting deployment secrets:

~~~sh
docker compose --env-file /dev/null -f docker-compose.yaml config --no-interpolate --quiet
~~~

For map changes:

~~~sh
npm --prefix maps run build
~~~

For Terraform changes:

~~~sh
terraform fmt -check -recursive terraform
cd terraform/aws   # or terraform/azure
terraform init -backend=false
terraform validate
~~~

Also inspect the generated plan in a non-production environment before applying infrastructure changes. Do not apply infrastructure or run a deployment as part of a pull request unless it is explicitly coordinated.

## Commits and pull requests

Use concise Conventional Commits, for example:

- `feat: add a self-hosted service`
- `fix: preserve encrypted environment values`
- `docs: clarify Azure deployment`
- `chore: update container versions`

Pull requests should:

- Explain the problem and the chosen solution
- Stay limited to one logical change
- Include documentation when setup or behavior changes
- List the validation commands that were run
- Call out migration, downtime, cost, security, and compatibility implications
- Avoid unrelated formatting or generated-file churn
- Contain no secrets or production-specific identifiers

By submitting a contribution, you agree that it may be distributed under the project's MIT License.
