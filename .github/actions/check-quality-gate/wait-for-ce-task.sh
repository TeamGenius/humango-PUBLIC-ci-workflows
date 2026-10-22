#!/usr/bin/env bash
# Waits for the SonarQube background (CE) task referenced by $REPORT_FILE to finish.
# Bounded by $TIMEOUT_SECONDS (0 = no bound) and fails clearly on FAILED/CANCELED, instead of
# letting the quality gate check query a null analysisId.
# Missing/invalid report files are left for the caller's check script to report.
set -euo pipefail

report_file="${REPORT_FILE:-.scannerwork/report-task.txt}"
timeout_seconds="${TIMEOUT_SECONDS:-600}"
poll_interval_seconds="${POLL_INTERVAL_SECONDS:-5}"

if ! [[ "$timeout_seconds" =~ ^[0-9]+$ ]]; then
  echo "::error::timeout-seconds must be a non-negative integer (got '$timeout_seconds')"
  exit 1
fi
if ! [[ "$poll_interval_seconds" =~ ^[1-9][0-9]*$ ]]; then
  echo "::error::poll-interval-seconds must be a positive integer (got '$poll_interval_seconds')"
  exit 1
fi

if [[ ! -f "$report_file" ]]; then
  echo "Info: $report_file not found; skipping background task wait"
  exit 0
fi

ce_task_url="$(sed -n 's/^ceTaskUrl=\(.*\)/\1/p' "$report_file")"
if [[ -z "$ce_task_url" ]]; then
  echo "Info: no ceTaskUrl in $report_file; skipping background task wait"
  exit 0
fi

deadline=$((SECONDS + timeout_seconds))
while true; do
  # Token comes from the environment; not a hardcoded credential.
  task="$(curl --silent --fail --show-error --user "${SONAR_TOKEN}:" "$ce_task_url")" # gitleaks:allow
  status="$(jq -r '.task.status // empty' <<< "$task")"

  case "$status" in
    SUCCESS)
      echo "Info: SonarQube background task finished (SUCCESS)"
      exit 0
      ;;
    FAILED | CANCELED)
      error_message="$(jq -r '.task.errorMessage // "no error message returned"' <<< "$task")"
      echo "::error::SonarQube background task $status: $error_message ($ce_task_url)"
      exit 1
      ;;
    PENDING | IN_PROGRESS)
      ;;
    *)
      echo "::error::Unexpected SonarQube background task status '$status' ($ce_task_url)"
      exit 1
      ;;
  esac

  if [[ "$timeout_seconds" -gt 0 && "$SECONDS" -ge "$deadline" ]]; then
    echo "::error::Timed out after ${timeout_seconds}s waiting for SonarQube background task (last status: $status, $ce_task_url)"
    exit 1
  fi

  echo "Waiting for SonarQube background task (status: $status)..."
  sleep "$poll_interval_seconds"
done
