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
  uses: TeamGenius/humango-PUBLIC-ci-workflows/.github/actions/determine-sonar-vars@main
  with:
    project-prefix: 'my-project'
    default-reference-branch: 'development'
```

Optional repo variable for the calling repository:
- `RELEASE_BRANCH_FOR_ALPHA_DEPLOY`: branch name or pattern used to treat matches as release/alpha for SonarQube (set in repo Variables). Leave blank to disable.

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
