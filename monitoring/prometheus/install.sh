#!/bin/bash

set -e

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts

helm repo update

helm upgrade --install prometheus \
prometheus-community/kube-prometheus-stack \
-n monitoring \
--create-namespace \
-f monitoring/prometheus/values.yaml