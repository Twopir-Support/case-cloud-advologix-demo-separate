#!/usr/bin/env bash
# Deploy Matter Management to a Salesforce org, assign access and load sample data.
#   SF_AUTH_URL  (optional) SFDX auth URL; if set, the org is logged in under $SF_ALIAS
#   SF_ALIAS     org alias (default: lch-sdo)
#   SEED=0       skip loading sample data
set -euo pipefail
cd "$(dirname "$0")/.."
ALIAS="${SF_ALIAS:-sdo}"

if [ -n "${SF_AUTH_URL:-}" ]; then
  tmp="$(mktemp)"; printf '%s' "$SF_AUTH_URL" > "$tmp"
  sf org login sfdx-url --sfdx-url-file "$tmp" --alias "$ALIAS"
  rm -f "$tmp"
fi

TESTS=$(ls force-app/main/default/classes/*Test.cls | xargs -n1 basename | sed 's/.cls$//' | sed 's/^/--tests /' | tr '\n' ' ')
deploy() { sf project deploy start --target-org "$ALIAS" --source-dir force-app --wait 60 --test-level RunSpecifiedTests $TESTS; }
MM_SKIP_OVERRIDES=1 python3 scripts/generate_metadata.py && python3 scripts/generate_pages.py && deploy   # pages first
python3 scripts/generate_metadata.py && deploy                                                              # then app page assignments

sf org assign permset --name Matter_Management_User --target-org "$ALIAS" || true

if [ "${SEED:-1}" = "1" ]; then
  for step in 1-reference 2-intakes 3-matters 4-billing 5-casecloud-extras; do
    echo "Loading sample data: $step"
    sf apex run --file "scripts/apex/seed-$step.apex" --target-org "$ALIAS" | grep -E "Step|Error|error|Exception" || true
  done
fi
sf apex run --file scripts/apex/schedule-jobs.apex --target-org "$ALIAS" >/dev/null
echo "Done. Open the org, App Launcher > Matter Management."
