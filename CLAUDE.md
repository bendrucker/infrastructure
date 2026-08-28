# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Personal infrastructure managed by Terraform. Uses Terraform Cloud (HCP Terraform) as the remote backend with auto-apply enabled.

## Commands

- `terraform init -backend=false` — initialize locally without backend credentials
- `terraform fmt` — format all `.tf` files (CI auto-commits formatting fixes on PRs)
- `terraform validate` — validate configuration after init

Plans and applies for the root module run remotely via Terraform Cloud (`app.terraform.io`, org `bendrucker`, workspace `infrastructure`). There is no local apply workflow for it. `bootstrap` is the exception and applies locally, per `bootstrap/README.md`.

## Architecture

Two independent Terraform root modules:

- **Root (`/`)** — primary infrastructure: Cloudflare DNS for `bendrucker.me`, S3 archive buckets (documents, photos) via the `archive` module, IAM Identity Center, GitHub Actions OIDC. It is also the control plane for app repos that manage their own infrastructure: it creates their Terraform Cloud workspaces, mints their Cloudflare tokens, and writes their GitHub Actions secrets, so this workspace can write into other repositories. Providers: AWS (`us-east-1`), Cloudflare, `tfe`, `github`. Authenticates to AWS via OIDC, with no static key.
- **`/bootstrap`** — what must exist before Terraform Cloud can run: the AWS OIDC provider and execution role the root module assumes, the workspace itself (`tfe_workspace`), and the `TFC_AWS_*` variables. Runs locally under `aws sso login` with state committed to git, so it holds no secrets. Providers: `tfe`, AWS.

Dependabot manages weekly provider version bumps for both roots and GitHub Actions.

## Modules

- `modules/archive` — S3 bucket with a lifecycle rule that transitions objects under the `Archive/` prefix to Glacier after 1 day. Parameterized by `name`.
- `modules/app-workspace`: the Terraform Cloud workspace an app repo's `infra/` root runs in, plus its `CLOUDFLARE_API_TOKEN` env variable. `working_directory` and `trigger_patterns` are fixed to `infra`. Per-repo token policies and GitHub Actions secrets stay in the repo's top-level `.tf` file.

## CI

GitHub Actions on pull requests:
- `tflint` via reviewdog
- `terraform fmt` with auto-commit if formatting changes are needed

Both run at the repository root without recursion, so neither covers `bootstrap/`. The `terraform-check.sh` hook validates both roots locally.

Terraform Cloud runs plan on PR and apply on merge to `main`. To monitor runs after merge, use the TFC API via `curl` with `$TFE_TOKEN` (set via `terraform login`). Fetch apply details from `/api/v2/applies/{id}` to get the `log-read-url`, then fetch logs from that URL.

## Conventions

- Provider version constraints use pessimistic operator (`~>`) in `versions.tf`
- Backend configuration lives in `terraform.tf` (root only; `bootstrap` has no backend)
- Provider configuration lives in `providers.tf`
- Resources are grouped by domain into top-level `.tf` files (`dns.tf`, `documents.tf`, `photography.tf`)
- `import` blocks are colocated with the resources they import
