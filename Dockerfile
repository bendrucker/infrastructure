FROM hashicorp/terraform

WORKDIR /scripts
COPY *.sh .
RUN /scripts/install.sh

WORKDIR /terraform
COPY . ./

ENV TF_DATA_DIR=/data
RUN terraform init