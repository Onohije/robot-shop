#!/usr/bin/env bash
# Quick checks that each "Done means" item is working. Run from the robot-shop repo root.
NS=monitoring
echo "== Pods not Running (should be empty) =="
kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded | grep -E "robot-shop|monitoring" || echo "none"

echo; echo "== Prometheus sees the probes (expect 4 services with value 1) =="
kubectl run promq --rm -i -n $NS --restart=Never --image=curlimages/curl:8.11.1 -q -- \
  curl -s "http://monitoring-kube-prometheus-prometheus.monitoring:9090/api/v1/query?query=probe_success" \
  | grep -o '"service":"[a-z]*"[^]]*"[01]"' || echo "no probe data yet (wait 1-2 minutes)"

echo; echo "== Loki has robot-shop logs (expect a list of service names) =="
kubectl run lokiq --rm -i -n $NS --restart=Never --image=curlimages/curl:8.11.1 -q -- \
  curl -s "http://loki.monitoring:3100/loki/api/v1/label/service/values" || true

echo; echo "== SLO rule loaded =="
kubectl get prometheusrule -n $NS robot-shop-slo

echo; echo "== Shipping is auto-instrumented (expect a javaagent / OTEL line) =="
kubectl get pod -n robot-shop -l service=shipping -o yaml | grep -m3 -E "javaagent|OTEL_SERVICE_NAME" || echo "not injected yet"
