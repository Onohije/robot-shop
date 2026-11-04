#!/usr/bin/env bash
# Capstone 2: installs the whole observability stack on the cluster.
# Run from the robot-shop repo root:   bash scripts/install-observability.sh
# Optional: export SLACK_WEBHOOK_URL="https://hooks.slack.com/services/..." first, to enable Slack alerts.
set -euo pipefail

NS=monitoring
echo "==> Helm repositories"
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null 2>&1 || true
helm repo add grafana https://grafana.github.io/helm-charts >/dev/null 2>&1 || true
helm repo add fluent https://fluent.github.io/helm-charts >/dev/null 2>&1 || true
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts >/dev/null 2>&1 || true
helm repo update || echo "(repo update had a hiccup, continuing with cached indexes)"

echo "==> 1/7 Prometheus, Grafana, Alertmanager"
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  -n $NS --create-namespace --version 92.17.1 \
  -f monitoring/kube-prometheus-values.yaml --wait --timeout 10m

echo "==> 2/7 Loki (log storage)"
helm upgrade --install loki grafana/loki -n $NS --version 7.5.0 \
  -f monitoring/loki-values.yaml --wait --timeout 10m

echo "==> 3/7 Fluent Bit (log shipper, one pod per node)"
helm upgrade --install fluent-bit fluent/fluent-bit -n $NS \
  -f monitoring/fluent-bit-values.yaml --wait --timeout 5m

echo "==> 4/7 Blackbox exporter (availability + latency probes)"
helm upgrade --install blackbox prometheus-community/prometheus-blackbox-exporter -n $NS \
  -f monitoring/blackbox-values.yaml --wait --timeout 5m

echo "==> 5/7 Jaeger + OpenTelemetry Collector"
kubectl apply -f monitoring/jaeger.yaml -f monitoring/otel-collector.yaml
kubectl rollout status deployment/jaeger -n $NS --timeout=5m
kubectl rollout status deployment/otel-collector -n $NS --timeout=5m

echo "==> 6/7 OpenTelemetry Operator + auto-instrument the shipping service"
helm upgrade --install otel-operator open-telemetry/opentelemetry-operator -n $NS \
  --set manager.collectorImage.repository=otel/opentelemetry-collector-k8s \
  --set admissionWebhooks.certManager.enabled=false \
  --set admissionWebhooks.autoGenerateCert.enabled=true \
  --wait --timeout 5m
# The operator's webhook needs a few seconds before it accepts Instrumentation objects
for i in $(seq 1 12); do
  kubectl apply -f monitoring/instrumentation.yaml && break
  echo "   operator not ready yet, retrying in 10s..."; sleep 10
done
kubectl patch deployment shipping -n robot-shop --type merge \
  -p '{"spec":{"template":{"metadata":{"annotations":{"instrumentation.opentelemetry.io/inject-java":"true"}}}}}'
kubectl rollout status deployment/shipping -n robot-shop --timeout=5m

echo "==> 7/7 SLO rules, dashboard, Slack alerts"
kubectl apply -f monitoring/slo-rules.yaml -f monitoring/dashboard-configmap.yaml
if [ -n "${SLACK_WEBHOOK_URL:-}" ]; then
  kubectl create secret generic slack-webhook -n $NS --from-literal=url="$SLACK_WEBHOOK_URL" \
    --dry-run=client -o yaml | kubectl apply -f -
  kubectl apply -f monitoring/alertmanager-slack.yaml
  echo "   Slack alerts enabled"
else
  echo "   SLACK_WEBHOOK_URL not set: skipped Slack. Set it and re-run this script to enable."
fi

echo
echo "Done. Everything in $NS:"
kubectl get pods -n $NS
echo
echo "Grafana password:"
kubectl get secret -n $NS monitoring-grafana -o jsonpath="{.data.admin-password}" | base64 -d; echo
cat <<'MSG'

Open the UIs (each in its own terminal):
  kubectl port-forward svc/monitoring-grafana -n monitoring 3000:80                 -> http://localhost:3000  (admin)
  kubectl port-forward svc/jaeger -n monitoring 16686:16686                         -> http://localhost:16686
  kubectl port-forward svc/monitoring-kube-prometheus-prometheus -n monitoring 9090 -> http://localhost:9090
  kubectl port-forward svc/monitoring-kube-prometheus-alertmanager -n monitoring 9093 -> http://localhost:9093
Dashboard: Grafana -> Dashboards -> "Robot Shop: Requests, Errors, Latency"
MSG
