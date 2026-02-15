> [!WARNING]
> **IMPORTANT**: This repository is PUBLIC. Please review all changes carefully before commiting and pushing.

# humango-PUBLIC-ci-workflows



This repo contains shared ci workflows across all humango repos

## pre-commit setup

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