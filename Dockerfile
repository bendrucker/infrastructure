FROM hashicorp/terraform

WORKDIR /scripts
COPY scripts .
RUN apk add libc6-compat && ./install.sh

WORKDIR /terraform
COPY . ./

ENV TF_DATA_DIR=/data
RUN terraform init
