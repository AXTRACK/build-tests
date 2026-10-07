# Security Policy

## Supported versions

`AXTRACK/build-tests` is operated as a continuously maintained execution service rather than a versioned package.

| Version / branch | Supported |
| --- | --- |
| Current `main` | Yes |
| Historical commits, stale branches, and forks | No |

Security fixes are made against the current trusted `main` branch. Reports about behavior that exists only in an old commit, abandoned branch, or fork are normally out of scope unless the same issue is present in current `main`.

## Reporting a vulnerability

Please report security vulnerabilities through GitHub's **private vulnerability reporting** for this repository:

1. Open the repository's **Security and quality** tab.
2. Open **Advisories**.
3. Select **Report a vulnerability**.
4. Submit the report privately.

Do **not** open a public Issue, Discussion, or pull request for a suspected security vulnerability.

A useful report should include:

- a concise summary of the vulnerability;
- the affected workflow, script, or control-plane behavior;
- security impact and realistic attack conditions;
- reproducible steps or a proof of concept when practical;
- whether the issue is known to affect current `main`;
- any mitigation or fix ideas you have already identified.

Do not include real credentials, access tokens, private repository contents, customer data, or other secrets in the report. Use synthetic or redacted evidence wherever possible.

## Security-sensitive areas

This repository is a public deterministic execution provider for AXTRACK repositories. It accepts tightly constrained requests and can use a read-only credential to check out allowlisted private source repositories at exact commit SHAs.

Reports are especially relevant when they involve:

- bypass of the allowed actor, repository, profile, or exact-SHA validation;
- command, expression, or workflow injection through issue content or workflow inputs;
- execution of an unintended script, repository, revision, or test profile;
- exposure, misuse, persistence, or privilege expansion of source-read credentials or other secrets;
- unintended write access to private source repositories;
- workflow-permission escalation;
- modification or bypass of the trusted `main` control plane;
- leakage of private source, credentials, or sensitive runtime data through logs, artifacts, comments, or error output;
- a way for untrusted public input to obtain execution beyond the repository's documented authorization boundary.

Ordinary test failures, unsupported test profiles, feature requests, and non-security reliability problems should be reported through normal GitHub Issues instead.

## Coordinated disclosure

Please keep vulnerability details private while the report is being assessed and, when applicable, while a fix is being prepared. Use the private GitHub advisory thread for follow-up information and coordination.

This repository does not publish a fixed response-time SLA. Maintainer updates and any disclosure timing will be coordinated through the private report.

