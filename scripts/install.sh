#!/usr/bin/env sh

set -euf

KUBECTL_VERSION=${KUBECTL_VERSION:-1.9.2}

curl --silent "https://storage.googleapis.com/kubernetes-release/release/v${KUBECTL_VERSION}/bin/linux/amd64/kubectl" > /usr/local/bin/kubectl
chmod +x /usr/local/bin/kubectl

PLUGIN_DIRECTORY="$HOME/.terraform.d/plugins/linux_amd64"

downlod_provider() {
  local url=$1

  mkdir -p "$PLUGIN_DIRECTORY"

  curl \
    --silent \
    --location \
    "$url" \
    | tar -xzf - -C "$PLUGIN_DIRECTORY" --strip 1
}

PROVIDER_CT_VERSION=${PROVIDER_CT_VERSION:-0.2.0}
downlod_provider "https://github.com/coreos/terraform-provider-ct/releases/download/v${PROVIDER_CT_VERSION}/terraform-provider-ct-v${PROVIDER_CT_VERSION}-linux-amd64.tar.gz"

PROVIDER_HELM_VERSION=${PROVIDER_HELM_VERSION:-0.4.0}
downlod_provider "https://github.com/mcuadros/terraform-provider-helm/releases/download/v${PROVIDER_HELM_VERSION}/terraform-provider-helm_v${PROVIDER_HELM_VERSION}_linux_amd64.tar.gz"

HELM_BIN_VERSION=${HELM_BIN_VERSION:-2.8.0}
HELM_BIN_PATH="/usr/local/bin/helm"
curl \
  --silent \
  "https://kubernetes-helm.storage.googleapis.com/helm-v${HELM_BIN_VERSION}-linux-amd64.tar.gz" \
  | tar xzf - -C /tmp --strip 1
mv /tmp/helm "$HELM_BIN_PATH"
chmod +x "$HELM_BIN_PATH"

helm init --client-only
