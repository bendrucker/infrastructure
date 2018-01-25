FROM hashicorp/terraform

WORKDIR /scripts
COPY scripts .
RUN ./install.sh

WORKDIR /terraform
COPY . ./

ENV TF_DATA_DIR=/data
RUN terraform init
