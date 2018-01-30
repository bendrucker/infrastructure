#!/usr/bin/env sh

kubectl apply \
  --filename ./resources \
  --recursive \
  --prune \
  --all
