#!/usr/bin/env sh

PLUGIN_DIRECTORY="$HOME/.terraform.d/plugins/linux_amd64"
PROVIDER_CT_VERSION=${PROVIDER_CT_VERSION:-0.2.0}

mkdir -p "$PLUGIN_DIRECTORY"
curl \
  --silent \
  --location \
  "https://github.com/coreos/terraform-provider-ct/releases/download/v${PROVIDER_CT_VERSION}/terraform-provider-ct-v${PROVIDER_CT_VERSION}-linux-amd64.tar.gz" \
  | tar -xzf - -C "$PLUGIN_DIRECTORY" --strip 1