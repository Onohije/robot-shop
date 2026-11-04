# SLO and Error Budget Policy: Robot Shop

## Service and scope

Stan's Robot Shop on EKS. Focus services: **web, catalogue, cart, payment**.

## SLI (what we measure)

**Availability:** the share of health probes that succeed.

A blackbox exporter calls each focus service every 15 seconds:

| Service | Probe |
|---|---|
| web | `GET http://web:8080/` |
| catalogue | `GET http://catalogue:8080/health` |
| cart | `GET http://cart:8080/health` |
| payment | `GET http://payment:8080/health` |

A probe succeeds when it gets a 2xx response within 10 seconds.

```
SLI = successful probes / total probes
PromQL: avg by (service) (avg_over_time(probe_success{service=~"web|catalogue|cart|payment"}[5m]))
Recording rule: robotshop:availability:ratio_5m
```

## SLO (the target)

**99% of probes succeed, per service, over a rolling 30 days.**

## Error budget

The budget is the 1% of probes allowed to fail.

| Window | Allowed downtime |
|---|---|
| 30 days | 7 h 12 min |
| 7 days | 1 h 41 min |
| 1 day | 14 min 24 s |

Shown live on the dashboard panel "Error budget remaining".

## Alerting

| Alert | Condition | Severity | Goes to |
|---|---|---|---|
| `RobotShopAvailabilityBelowSLO` | 5-minute availability below 99% for 2 minutes | critical | Slack `#alerts` |

Every alert links to the runbook: [runbook-availability.md](runbook-availability.md).

## Error budget policy

| Budget remaining | What we do |
|---|---|
| **More than 50%** | Normal work. Releases go out as usual. |
| **25% to 50%** | Releases need a second reviewer. The top reliability issue goes into the next sprint. |
| **Less than 25%** | Feature releases pause. Only fixes and reliability work ship. |
| **Spent (0%)** | Release freeze until the budget recovers. A postmortem is required for each incident that used budget. |

Budget spent by planned, announced maintenance does not count.

## Known gaps

- Probes test **health endpoints**, not full user journeys (e.g. checkout). A synthetic checkout probe would be a stronger SLI.
- Request **error rate** is measured from web's access logs (Loki) and shown on the dashboard, but not yet alerted on.
