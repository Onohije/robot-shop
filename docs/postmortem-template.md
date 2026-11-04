# Postmortem: <short title>

**Date:** <YYYY-MM-DD>  
**Author:** Blessing Onohije Igbadume  
**Status:** Draft / Final  
**Severity:** <critical / major / minor>

> Blameless: this document describes what happened and how the system allowed it, not who is at fault.

## Summary

<2–3 sentences: what broke, who was affected, how long, how it was fixed.>

## Impact

- **Services affected:** <e.g. cart>
- **Duration:** <start → end, total minutes>
- **User impact:** <e.g. customers could not add items to cart>
- **Error budget used:** <minutes, and % of the 30-day budget>

## Timeline (all times <timezone>)

| Time | Event |
|---|---|
| hh:mm | Fault introduced (<what>) |
| hh:mm | `RobotShopAvailabilityBelowSLO` fired in Slack |
| hh:mm | Investigation started (runbook step 1) |
| hh:mm | Mitigation applied: <action> |
| hh:mm | Service recovered, alert resolved |
| hh:mm | Root cause confirmed |

## Detection

<How we found out: the alert, a dashboard, a user? How long from fault to alert?>

## Mitigation

<What we did to restore service, and why that action.>

## Root cause

<The underlying technical cause. Use "5 whys" if helpful.>

## What went well

- 
## What went wrong

- 
## Where we got lucky

- 

## Action items

| Action | Type | Owner | Due |
|---|---|---|---|
| <e.g. add a readiness probe to cart> | prevent | | |
| <e.g. alert on error rate from logs> | detect | | |
| <e.g. add this case to the runbook> | mitigate | | |
