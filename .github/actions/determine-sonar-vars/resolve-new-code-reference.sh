#!/usr/bin/env bash
# Picks the SonarQube new-code reference branch for one project per repository (single-project
# mode of determine-sonar-vars). Prints the branch name, or nothing to use the project's
# "previous version" setting.
#
#   pull request                       -> nothing (SonarQube compares a PR with its target)
#   development, master, main, alpha   -> nothing (a branch cannot reference itself)
#   release line (release/*, historical/*, hotfix/R<x>.M<y>...), ordered by release number R<x>.M<y>:
#     hotfix/R<x>.M<y>...              -> its release (release/* or historical/* named R<x>.M<y>), else
#                                         the highest lower release
#     release/*, historical/*          -> the highest release strictly lower than its own; never a
#                                         branch of the same release (e.g. its own hotfix, if one was
#                                         left alive by mistake)
#     ... without a release number     -> the most recent other release/* or historical/* branch
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
  local response
  response="$(curl --silent --fail --show-error --max-time 20 --user "${SONAR_TOKEN:?}:" \
    "${SONAR_HOST_URL:?}/api/project_branches/list?project=${PROJECT_KEY:?}")"
  if command -v jq >/dev/null 2>&1; then
    jq -r '.branches[] | select(.type == "BRANCH") | .name' <<< "$response"
  else
    python3 -c 'import json,sys; [print(b["name"]) for b in json.load(sys.stdin)["branches"] if b.get("type") == "BRANCH"]' <<< "$response"
  fi
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

# "major minor" of a release name (R3.M9 in release/sprint-53-R3.M9, hotfix/R3.M9.001, ...)
release_number() {
  if [[ "$1" =~ [Rr]([0-9]+)\.[Mm]([0-9]+) ]]; then
    echo "${BASH_REMATCH[1]} ${BASH_REMATCH[2]}"
  fi
}

# Release-line branches as "major minor kind patch name", where kind ranks release (3) over
# historical (2) over hotfix (1) for the same release; input order (most recent commit first)
# breaks remaining ties
versioned_release_line() {
  local candidate number kind patch
  while IFS= read -r candidate; do
    number="$(release_number "$candidate")"
    [[ -z "$number" ]] && continue
    case "$candidate" in
      release/*) kind=3 ;;
      historical/*) kind=2 ;;
      hotfix/*) kind=1 ;;
      *) continue ;;
    esac
    patch=0
    [[ "$candidate" =~ [Mm][0-9]+\.([0-9]+) ]] && patch="$((10#${BASH_REMATCH[1]}))"
    echo "$number $kind $patch $candidate"
  done < <(recent_branches release/ historical/ hotfix/)
}

candidates=()
if [[ "$branch" =~ ^(release/|historical/|hotfix/[Rr][0-9]+\.[Mm][0-9]+) ]]; then
  own="$(release_number "$branch")"
  if [[ -n "$own" ]]; then
    read -r own_major own_minor <<< "$own"
    sorted="$(versioned_release_line | sort -s -k1,1nr -k2,2nr -k3,3nr -k4,4nr)"
    if [[ "$branch" == hotfix/* ]]; then
      # its own release first
      while read -r major minor kind patch candidate; do
        [[ -n "$candidate" && "$major $minor" == "$own_major $own_minor" && $kind -ge 2 ]] && candidates+=("$candidate")
      done <<< "$sorted"
    fi
    # then the releases strictly lower than its own, highest first
    while read -r major minor kind patch candidate; do
      [[ -z "$candidate" ]] && continue
      if (( major < own_major || (major == own_major && minor < own_minor) )); then
        candidates+=("$candidate")
      fi
    done <<< "$sorted"
  else
    while IFS= read -r candidate; do
      candidates+=("$candidate")
    done < <(recent_branches release/ historical/)
  fi
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
