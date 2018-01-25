# infrastructure

> My personal infrastructure configuration, managed by [Terraform](https://www.terraform.io/)

## Purpose

This repository includes configuration for infrastructure I operate for personal use, primarily on AWS. I work as a platform/infrastructure engineer and found the lack of open source infrastructure projects made it a lot harder to build practical knowledge. 

I'm sharing my setup both as a way to experiment but also to share some of the lessons I've learned building and scaling infrastructure for startups. This level of automation and complexity is far from necessary for your personal projects—this is mostly a learning exercise for me and you.

## Installing

* [docker](https://docs.docker.com/engine/installation/)
* [docker-compose](https://docs.docker.com/compose/install/)
* [docker-ssh-agent-forward](https://github.com/uber-common/docker-ssh-agent-forward) (allows containers to connect to ssh-agent and securely use your private keys)

## Usage

```sh
docker-compose run terraform apply
```
