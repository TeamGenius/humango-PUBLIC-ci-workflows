> [!WARNING]
> **IMPORTANT**: This repository is PUBLIC. Please review all changes carefully before commiting and pushing.

# Humango Public CI Workflows

Shared GitHub Actions workflows and composite actions used across Humango projects.

## Available Actions

### SonarQube Actions
- **determine-sonar-vars** - Calculate SonarQube project key and reference branch
- **run-sonarqube-scan** - Execute SonarQube scanner
- **check-quality-gate** - Verify SonarQube quality gate status. Waits for the SonarQube background task for at most `timeout-seconds` (default 600, `0` = unbounded) and fails clearly if the task is `FAILED`/`CANCELED` (prefer `wait-for-quality-gate: 'true'` on run-sonarqube-scan)

#### SonarQube branch and pull request analysis

The SonarQube server runs the community branch plugin, which detects the analysis type from the
GitHub Actions environment: a `pull_request` run is analyzed as a pull request (and decorated on
GitHub), anything else as a branch named after `GITHUB_REF_NAME`.

When the code that is checked out can differ from the workflow ref (for example a
`workflow_dispatch` with a `branch` input), pass it to `run-sonarqube-scan` so the analysis is not
recorded under the wrong branch:

```yaml
- uses: TeamGenius/humango-PUBLIC-ci-workflows/.github/actions/run-sonarqube-scan@master
  with:
    # ...
    branch-name: ${{ inputs.branch || github.ref_name }}
    wait-for-quality-gate: 'true'
```

With one SonarQube project per repository (branches and pull requests inside it), call
`determine-sonar-vars` with `single-project: 'true'` (plus `sonar-host-url` / `sonar-token`) and
pass its outputs to `run-sonarqube-scan`. The project key is `project-prefix`, and the new-code
reference is chosen per analyzed branch (`resolve-new-code-reference.sh`); release-line branches are
ordered by release number (`R<x>.M<y>` in the name), not by commit date:

| Analyzed | New-code reference |
| --- | --- |
| Pull request | none: SonarQube compares a PR with its target branch |
| `development`, `master`, `main`, `alpha` | none: the project's setting ("previous version") |
| `hotfix/R<x>.M<y>...` | its release (`release/*` or `historical/*` named `R<x>.M<y>`), else the highest lower release |
| `release/*`, `historical/*` | the highest release strictly lower than its own (never a branch of the same release, e.g. its own hotfix) |
| release-line branch without a release number | the most recent other `release/*` or `historical/*` branch |
| other `hotfix/*` | `master` |
| anything else | `development` |

A reference is only used when it already exists as a branch in the SonarQube project; otherwise
the project's setting applies. For an analysis rooted in a subdirectory (e.g. a Flutter app), set
`project-base-dir` on `run-sonarqube-scan`.

### Utility Actions
- **cancel-on-failure** - **DEPRECATED, unused and slated for removal.** It never actually runs after a failure (callers invoke it as a plain step) and needs `actions: write`, which callers do not grant. Do not add new usages.
- **upload-coverage** - Upload coverage reports as artifacts

### Available Workflows
- **check-branch.yml** - Branch guardrail for deployment restrictions
- **print-commit-info.yml** - Display commit information
- **combine-coverage-sonar.yml** - Combine coverage and run SonarQube analysis

## Usage Examples

### Using Shared Actions
```yaml
- name: Determine SonarQube settings
  id: sonar-vars
  uses: TeamGenius/humango-PUBLIC-ci-workflows/.github/actions/determine-sonar-vars@master
  with:
    single-project: 'true'
    project-prefix: 'humango-backend'
    current-branch: ${{ github.ref_name }}
    sonar-host-url: ${{ vars.SONAR_HOST_URL }}
    sonar-token: ${{ secrets.SONAR_TOKEN }}

- name: Run SonarQube scan
  uses: TeamGenius/humango-PUBLIC-ci-workflows/.github/actions/run-sonarqube-scan@master
  with:
    sonar-project-key: ${{ steps.sonar-vars.outputs.project-key }}
    sonar-project-version: ${{ vars.SONAR_PROJECT_VERSION }}
    sonar-reference-branch: ${{ steps.sonar-vars.outputs.reference-branch }}
    sonar-token: ${{ secrets.SONAR_TOKEN }}
    sonar-host-url: ${{ vars.SONAR_HOST_URL }}
    project-settings-file: 'sonar-project.properties'
    # PRs are gated by the required "SonarQube Code Analysis" check; branch analyses wait here
    wait-for-quality-gate: ${{ github.event_name != 'pull_request' }}
```

`sonar-project-version` drives the "previous version" new-code period of `development`, `master`
and `alpha`: bump it at each release (humango and humango-bff use the `SONAR_PROJECT_VERSION`
repository variable, humango-mobile the `pubspec.yaml` version).

**Legacy mode** (`single-project` unset): one SonarQube project per branch type
(`<prefix>`, `<prefix>-release`, `<prefix>-master`), selected from `gcloud-project`, `pr-base-ref`,
`default-reference-branch`, `release-branch-alpha` / `hotfix-branch-alpha` and the
`RELEASE_BRANCH_FOR_ALPHA_DEPLOY` repository variable. No workflow uses it since 2026-10-22; it
will be removed together with those projects (about 2026-11-22). Do not use it in new workflows.

### Using Shared Workflows
```yaml
jobs:
  check-branch:
    uses: TeamGenius/humango-PUBLIC-ci-workflows/.github/workflows/check-branch.yml@main
    with:
      gcloud_project: 'my-gcp-project'
```

## Version Pinning

We recommend using `@master` for the latest version, but you can pin to specific commits:
```yaml
uses: TeamGenius/humango-PUBLIC-ci-workflows/.github/actions/setup-flutter@a1b2c3d
```

## Development

### pre-commit setup

- Install precommit (globally)

```sh
sudo apt install pipx
pipx install pre-commit
```

Alternatively on Mac

```sh
brew install pre-commit
```

- Check with `pre-commit --version`

```bash
pre-commit install
```

**Note:** To avoid pre-commit check when you want to commit add `--no-verify` in args. ex: `git commit -m "changes" --no-verify`

## Contributing

When making changes to shared workflows:
1. Test in a fork or feature branch first
2. Consider backward compatibility
3. Update this README with any new inputs or breaking changes
4. Notify teams using these workflows of any breaking changes
```
