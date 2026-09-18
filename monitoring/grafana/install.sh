#!/bin/bash

set -e

helm repo add grafana https://grafana.github.io/helm-charts

helm repo update

helm upgrade --install grafana \
grafana/grafana \
-n monitoring \
-f monitoring/grafana/values.yaml