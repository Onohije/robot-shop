#!/usr/bin/env bash
# Removes Capstone 2 from the cluster in a safe order, so nothing is left billing.
# Then destroy the cluster itself with Terraform (last step printed below).
set -uo pipefail

echo "==> Robot Shop (this also deletes the web Service's Classic Load Balancer)"
kubectl delete -f K8s/load-deployment.yaml -n robot-shop --ignore-not-found
helm uninstall robot-shop -n robot-shop
kubectl delete pvc --all -n robot-shop          # Redis disk is kept by default, delete it
echo "   waiting for the load balancer to be released..."
for i in $(seq 1 30); do
  kubectl get svc -n robot-shop web >/dev/null 2>&1 || break; sleep 5
done

echo "==> Observability stack"
helm uninstall otel-operator blackbox fluent-bit loki monitoring -n monitoring
kubectl delete -f monitoring/jaeger.yaml -f monitoring/otel-collector.yaml --ignore-not-found
kubectl delete pvc --all -n monitoring

echo
echo "Now destroy the cluster:"
echo "  cd ~/voting_app/example-voting-app/terraform && terraform destroy"
echo "Then confirm nothing is left (all should be empty):"
echo '  aws eks list-clusters'
echo '  aws elb describe-load-balancers --query "LoadBalancerDescriptions[].LoadBalancerName"'
echo '  aws elbv2 describe-load-balancers --query "LoadBalancers[].LoadBalancerName"'
echo '  aws ec2 describe-volumes --filters Name=status,Values=available --query "Volumes[].VolumeId"'
echo '  aws ec2 describe-addresses --query "Addresses[].PublicIp"'
