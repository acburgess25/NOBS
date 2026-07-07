# Security Policy

## Supported versions

NOBS is an early prototype. Security fixes land on `main` and are tagged in release notes when applicable. There is no long-term support promise yet.

## Reporting a vulnerability

**Please do not open public GitHub issues for exploitable security problems.**

Use [GitHub private security advisories](https://github.com/acburgess25/NOBS/security/advisories/new) or contact the repository owner through a private channel if you already have one.

- a description of the issue and likely impact;
- steps to reproduce;
- affected paths, versions, or commits if known.

We aim to acknowledge reports within a few business days. Coordinated disclosure is appreciated.

## Out of scope for public issues

- Home LAN IPs, tunnel credentials, device tokens, or `.env` values from your own deployment.
- Social engineering against a specific maintainer homelab.
- Findings that require physical access to an already-unlocked paired iPhone.

## Safe defaults we expect contributors to preserve

- Device-token authentication on state-changing Tank routes.
- No secrets, personal data, or production logs in Git.
- Approval gates before sensitive automation.
- Honest labeling of prototype versus shipped capability.

See also [`CONTRIBUTING.md`](CONTRIBUTING.md) and [`docs/AI_WORKFLOW.md`](docs/AI_WORKFLOW.md).
