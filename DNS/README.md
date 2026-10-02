# DNS

| Script | Purpose |
|---|---|
| `Check-DNS.ps1` | Validate forward (A), reverse (PTR) and CNAME records against an expected-values CSV; reports found/correct/duplicate per host |

**Prerequisites:** reachable DNS resolver; the expected-records CSV (HostName, suffix,
expected IP, CNAME, CNAMESuffix).
