#!/usr/bin/env python3
"""
scripts/health_check.py - basic health checker for the retail store services.

For every check: send an HTTP GET, mark it HEALTHY or UNHEALTHY, add a timestamp,
print the result and append it to a log file.

Why three checks and not just /actuator/health:
during the incidents the UI health endpoint kept answering {"status":"UP"} while
users got HTTP 500 on /catalog (Catalog was down). So the script also checks
Catalog directly and the page a user actually opens.

Usage:
    python3 scripts/health_check.py                 # default URLs below
    python3 scripts/health_check.py --log /tmp/hc.log
    python3 scripts/health_check.py --url http://10.0.2.15:8080/actuator/health

Exit code: 0 if everything is HEALTHY, 1 if anything is UNHEALTHY
(so it can be used from cron or a shell `if`).
"""

import argparse
import os
import sys
import time
import urllib.error
import urllib.request
from datetime import datetime

DEFAULT_CHECKS = [
    ("ui-health", "http://localhost:8080/actuator/health"),
    ("catalog-health", "http://localhost:8081/health"),
    ("ui-catalog-page", "http://localhost:8080/catalog"),
]
DEFAULT_LOG = os.path.expanduser("~/retail-logs/health_check.log")
TIMEOUT_SECONDS = 5


def check(url):
    """Return (status, http_code, detail, milliseconds)."""
    start = time.time()
    try:
        with urllib.request.urlopen(url, timeout=TIMEOUT_SECONDS) as resp:
            code = resp.status
            detail = "OK"
    except urllib.error.HTTPError as err:          # server answered with 4xx / 5xx
        code = err.code
        detail = err.reason
    except urllib.error.URLError as err:           # refused, DNS failure, timeout ...
        code = 0
        detail = str(err.reason)
    except Exception as err:                       # anything else, e.g. socket timeout
        code = 0
        detail = str(err)
    ms = int((time.time() - start) * 1000)
    status = "HEALTHY" if 200 <= code < 400 else "UNHEALTHY"
    return status, code, detail, ms


def main():
    parser = argparse.ArgumentParser(description="Retail store health checker")
    parser.add_argument("--url", action="append",
                        help="URL to check (can be repeated). Default: UI, Catalog and UI catalog page")
    parser.add_argument("--log", default=DEFAULT_LOG, help="result log file (default %(default)s)")
    args = parser.parse_args()

    checks = [("custom", u) for u in args.url] if args.url else DEFAULT_CHECKS
    os.makedirs(os.path.dirname(os.path.abspath(args.log)), exist_ok=True)

    all_ok = True
    with open(args.log, "a") as log:
        for name, url in checks:
            status, code, detail, ms = check(url)
            stamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            line = f"{stamp} {status:<9} {name:<16} {url} http={code} time={ms}ms {detail}"
            print(line)
            log.write(line + "\n")
            if status != "HEALTHY":
                all_ok = False

    return 0 if all_ok else 1


if __name__ == "__main__":
    sys.exit(main())
