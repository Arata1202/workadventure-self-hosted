# Security Policy

## Supported versions

Security fixes are applied to the latest commit on the `master` branch.

| Version | Supported |
| --- | --- |
| Latest `master` | Yes |
| Older commits | No |

This repository maintains deployment configuration rather than the upstream WorkAdventure application. Report vulnerabilities in WorkAdventure itself to the [upstream WorkAdventure project](https://github.com/workadventure/workadventure/security).

## Reporting a vulnerability

Do not report security vulnerabilities in a public issue, pull request, or discussion.

Use the repository's **Security** tab and select **Report a vulnerability** to submit a private report.

Include the following information when possible:

- A description of the vulnerability and its potential impact
- The affected commit and deployment area
- Reproduction steps or a minimal proof of concept
- Relevant Docker, WorkAdventure, Terraform, cloud provider, and operating-system versions
- Suggested mitigations, if known

Remove all secrets and production identifiers before submitting a report. Do not include dotenvx private keys, decrypted environment values, webhook URLs, tokens, credentials, Terraform state, SSH keys, hostnames, IP addresses, tenant IDs, resource IDs, or user data.

The maintainer will review the report, coordinate remediation and disclosure, and publish a security advisory when appropriate. Response times are best effort; this project does not provide a formal security SLA.

## Deployment security boundaries

Operators are responsible for securing their own infrastructure and deployment secrets. In particular:

- Keep dotenvx private keys outside the repository and restrict access to them.
- Do not expose internal WorkAdventure services or databases directly to the public internet.
- Restrict SSH, cloud credentials, storage credentials, webhooks, and administrative endpoints according to least privilege.
- Review Terraform plans and container image changes before applying them.
- Rotate any credential immediately if it may have been exposed.
