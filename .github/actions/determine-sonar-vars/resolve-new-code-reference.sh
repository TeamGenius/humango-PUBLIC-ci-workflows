#!/usr/bin/env bash
# Picks the SonarQube new-code reference branch for one project per repository (single-project
# mode of determine-sonar-vars). Prints the branch name, or nothing to use the project's
# "previous version" setting.
#
#   pull request                       -> nothing (SonarQube compares a PR with its target)
#   development, master, main, alpha   -> nothing (a branch cannot reference itself)
#   release line (release/*, historical/*, hotfix/R<x>.M<y>...)
#                                      -> for hotfix/R<x>.M<y>.<n>: the release branch of R<x>.M<y>;
#                                         otherwise / if absent: the most recent other release-line branch
#   other hotfix/*                     -> master (or main)
#   anything else (feature branches)   -> development
#
# A candidate is only used if it already exists as a branch in the SonarQube project, otherwise
# the analysis would have no usable new-code baseline.
#
# Env: EVENT_NAME, BRANCH, PROJECT_KEY, SONAR_HOST_URL, SONAR_TOKEN.
# SONAR_BRANCH_LIST_FILE (tests only): file with one SonarQube branch name per line, instead of the API.
set -euo pipefail

log() { echo "Info: $*" >&2; }

if [[ "${EVENT_NAME:-}" == pull_request* ]]; then
  log "pull request analysis: SonarQube compares it with its target branch"
  exit 0
fi

branch="${BRANCH:?BRANCH is required}"
if [[ "$branch" =~ ^(development|master|main|alpha)$ ]]; then
  log "'$branch' uses the project's new-code setting"
  exit 0
fi

sonar_branches() {
  if [[ -n "${SONAR_BRANCH_LIST_FILE:-}" ]]; then
    cat "$SONAR_BRANCH_LIST_FILE"
    return
  fi
  curl --silent --fail --show-error --max-time 20 --user "${SONAR_TOKEN:?}:" \
    "${SONAR_HOST_URL:?}/api/project_branches/list?project=${PROJECT_KEY:?}" \
    | jq -r '.branches[] | select(.type == "BRANCH") | .name'
}

# Remote branches under the given prefixes, most recent commit first, excluding the analyzed one
recent_branches() {
  local refspecs=() prefix
  for prefix in "$@"; do
    refspecs+=("+refs/heads/${prefix}*:refs/remotes/origin/${prefix}*")
  done
  git fetch --quiet --prune origin "${refspecs[@]}" >/dev/null 2>&1 || true
  local refs=()
  for prefix in "$@"; do
    refs+=("refs/remotes/origin/${prefix}")
  done
  git for-each-ref --sort=-committerdate --format='%(refname:short)' "${refs[@]}" 2>/dev/null \
    | sed 's#^origin/##' | grep -vxF "$branch" || true
}

candidates=()
if [[ "$branch" =~ ^(release/|historical/|hotfix/R[0-9]+\.M[0-9]+) ]]; then
  if [[ "$branch" =~ ^hotfix/(R[0-9]+\.M[0-9]+) ]]; then
    release="${BASH_REMATCH[1]}"
    while IFS= read -r candidate; do
      [[ "$candidate" =~ ^(release|historical)/.*${release//./\\.}([^0-9]|$) ]] && candidates+=("$candidate")
    done < <(recent_branches release/ historical/)
  fi
  while IFS= read -r candidate; do
    [[ "$candidate" =~ ^(release/|historical/|hotfix/R[0-9]+\.M[0-9]+) ]] && candidates+=("$candidate")
  done < <(recent_branches release/ historical/ hotfix/)
elif [[ "$branch" == hotfix/* ]]; then
  candidates=(master main)
else
  candidates=(development)
fi

if [[ ${#candidates[@]} -eq 0 ]]; then
  log "no reference candidate for '$branch'; using the project's new-code setting"
  exit 0
fi

if ! existing="$(sonar_branches)"; then
  log "could not list SonarQube branches of ${PROJECT_KEY:-?}; using the project's new-code setting"
  exit 0
fi

for candidate in "${candidates[@]}"; do
  if grep -qxF "$candidate" <<< "$existing"; then
    log "new-code reference for '$branch': '$candidate'"
    echo "$candidate"
    exit 0
  fi
done

log "none of the candidates for '$branch' is analyzed in SonarQube yet (${candidates[*]:0:5}); using the project's new-code setting"
