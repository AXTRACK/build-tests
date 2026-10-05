# AXTRACK build-tests

Public deterministic execution provider for AXTRACK repositories.

## Golden execution rule

Portable deterministic repository validation runs here, not on private GitHub-hosted Actions.

ChatGPT must submit a build-test request by creating an issue in this repository with the exact source commit SHA and an allowlisted profile. The default-branch workflow validates the actor, repository, SHA and profile before checking out private source with the read-only `CODEX_TEST_SOURCE_TOKEN`.

Example request:

```text
Title: [build-test] technical-architect full <short-sha>

source_repository: AXTRACK/technical-architect
source_sha: <40-character commit SHA>
profile: full
```

The issue is only a request envelope. Private source is never copied into public git history. The workflow reports PASS/FAIL with the exact source SHA and closes the request.

## Security

- The workflow definition and request policy are loaded from trusted `main`.
- Only allowlisted actors, source repositories and profiles are accepted.
- Checkout credentials are used only by `actions/checkout` and are not persisted.
- The requested source SHA must be an exact 40-character commit identity.
- Request text cannot select an arbitrary runner.

`.github/workflows/remote-private.yml` remains a low-level manual dispatch surface. ChatGPT automation must use the issue-based request contract above.
