# Runbook: RobotShopAvailabilityBelowSLO

**Alert meaning:** one of web, catalogue, cart or payment has failed more than 1% of its health probes for over 2 minutes. Customers are likely seeing errors.

**Goal:** mitigate first (get the service answering), then find the root cause.

## 1. Confirm (1 minute)

```bash
kubectl get pods -n robot-shop
```

Look for pods that are not `Running`, not `1/1` ready, or have a rising `RESTARTS` count.

Open Grafana → **Robot Shop: Requests, Errors, Latency**. Check which service is red and whether errors or latency jumped.

## 2. Mitigate (stop the bleeding)

Pick the first that fits:

| Symptom | Action |
|---|---|
| Pod `CrashLoopBackOff` / `Error` after a change | Roll back: `helm rollback robot-shop -n robot-shop` |
| Deployment scaled to 0 | `kubectl scale deployment <service> -n robot-shop --replicas=1` |
| Pod stuck / unhealthy, no recent change | `kubectl rollout restart deployment <service> -n robot-shop` |
| Pod `Pending` | `kubectl describe pod <pod> -n robot-shop` → check Events (resources, disk) |
| A dependency (mongodb, mysql, redis, rabbitmq) is down | Bring the dependency back first; the services then recover |

Then watch it recover:

```bash
kubectl get pods -n robot-shop -w
```

The alert resolves (Slack gets a RESOLVED message) once availability is back above 99%.

## 3. Find the root cause

```bash
kubectl describe pod <pod> -n robot-shop          # Events: why it failed or restarted
kubectl logs <pod> -n robot-shop --previous       # logs from the crashed container
kubectl get events -n robot-shop --sort-by=.lastTimestamp | tail -20
helm history robot-shop -n robot-shop             # was there a recent change?
```

In Grafana → **Explore → Loki**:

```
{namespace="robot-shop", service="<service>"} |~ `(?i)error|exception`
```

In Jaeger (`kubectl port-forward svc/jaeger -n monitoring 16686`), look for failing or slow spans.

## 4. Afterwards

- Note the start time, mitigation time and end time.
- Write a blameless postmortem: [postmortem-template.md](postmortem-template.md).
- Record the budget used against the [SLO](slo.md).
