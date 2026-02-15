> [!WARNING]
> **IMPORTANT**: This repository is PUBLIC. Please review all changes carefully before commiting and pushing.

# Humango Public CI Workflows

Shared GitHub Actions workflows and composite actions used across Humango projects.

## Available Actions

### SonarQube Actions
- **determine-sonar-vars** - Calculate SonarQube project key and reference branch
- **run-sonarqube-scan** - Execute SonarQube scanner
- **check-quality-gate** - Verify SonarQube quality gate status

### Utility Actions
- **cancel-on-failure** - Cancel workflow on job failure
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
