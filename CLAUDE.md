# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Personal infrastructure managed by Terraform. Uses Terraform Cloud (HCP Terraform) as the remote backend with auto-apply enabled.

## Commands

- `terraform init -backend=false` — initialize locally without backend credentials
- `terraform fmt` — format all `.tf` files (CI auto-commits formatting fixes on PRs)
- `terraform validate` — validate configuration after init

Plans and applies run remotely via Terraform Cloud (`app.terraform.io`, org `bendrucker`, workspace `infrastructure`). There is no local apply workflow.

## Architecture

Two independent Terraform root modules:

- **Root (`/`)** — primary infrastructure: Cloudflare DNS for `bendrucker.me`, S3 archive buckets (documents, photos) via the `archive` module. Providers: AWS (`us-east-1`), Cloudflare.
- **`/workspace`** — self-managing Terraform Cloud workspace configuration (`tfe_workspace`). Provider: `tfe`.

Dependabot manages weekly provider version bumps for both roots and GitHub Actions.

## Modules

- `modules/archive` — S3 bucket with a lifecycle rule that transitions objects under the `Archive/` prefix to Glacier after 1 day. Parameterized by `name`.

## CI

GitHub Actions on pull requests:
- `tflint` via reviewdog
- `terraform fmt` with auto-commit if formatting changes are needed

Terraform Cloud runs plan on PR and apply on merge to `main`. To monitor runs after merge, use the TFC API via `curl` with `$TFE_TOKEN` (set via `terraform login`). Fetch apply details from `/api/v2/applies/{id}` to get the `log-read-url`, then fetch logs from that URL.

## Conventions

- Provider version constraints use pessimistic operator (`~>`) in `versions.tf`
- Backend configuration lives in `terraform.tf`
- Provider configuration lives in `providers.tf`
- Resources are grouped by domain into top-level `.tf` files (`dns.tf`, `documents.tf`, `photography.tf`)
- `import` blocks are colocated with the resources they import
