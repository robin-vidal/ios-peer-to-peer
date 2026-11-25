# DevSecOps pipeline

This document explains which security tools run in CI, why each one was chosen, what makes a job fail, and which OWASP MASVS controls each tool provides evidence for. It is written as tools land, one section per tool.

## Principles

**One place to read the results: GitHub code scanning.** Every tool writes SARIF, the SARIF is uploaded under its own category, and alerts appear in the Security tab and on pull requests. SonarQube Cloud was rejected: on the free plan a project bound to a public repository is public too, so the findings would be world readable. Code scanning alerts require write access to the repository.

**Findings never reach the public log.** The repository is public, so are its Actions logs and artifacts. Every tool writes its results to a file, never to stdout, and no SARIF file is uploaded as a workflow artifact. Pull request annotations remain visible to anyone, so findings are fixed in the pull request before merge.

**No tool can fail silently.** Code scanning compares each upload with the previous one in the same category and closes every alert that is missing. An empty SARIF from a crashed tool would therefore close all its alerts as fixed. Every job checks that its tool ran and actually analysed something, and `.github/scripts/sarif-gate.sh` refuses a missing, empty or malformed SARIF before upload.

**Findings do not fail the job.** Tools that exit non-zero on findings are run so that only a crash fails the job (exit code 0 or 1 is accepted, anything else fails). Blocking a merge is the job of the branch ruleset on `main`, based on the security severity of new alerts.

**Everything is pinned.** Actions are pinned to commit SHAs, tool versions are pinned in the workflow `env`, and the shellcheck binary is verified against a SHA-256 checksum. Checkouts use `persist-credentials: false`, so the job token is not left in `.git/config` for the tools to read.

**The threat model is stated honestly.** The code is public, so anyone can run the same tools and reproduce the findings. Keeping alerts private avoids publishing a sorted list with our triage notes; it does not make weaknesses secret. Fixing quickly is the protection.

## Code scanning (`.github/workflows/code-scanning.yml`)

**Triggers:** every pull request, every push to `main`, weekly on Monday (vulnerabilities are published against dependencies that did not change), and manually.

**Shared scripts:**
- `sarif-from-json.sh` converts the JSON output of actionlint and shellcheck, which write no SARIF, into SARIF 2.1.0. It fails if the input is not JSON.
- `sarif-gate.sh` validates every SARIF before upload, then gives each rule without one a `security-severity` score (from the tool's HIGH/MEDIUM/LOW tags, otherwise from its level), so that the merge rule on `main` ranks every tool's alerts on the same scale. Known limitation: it currently tags lint findings as security too.

### gosec: Go security patterns

- **Checks:** the registry server for security anti-patterns: hardcoded credentials, weak cryptography, insecure TLS settings, injection, unsafe file paths, integer overflow on conversions.
- **Job fails when:** gosec could not load a package, read no Go file, or produced an invalid SARIF.
- **Alternatives:** Semgrep's Go rules overlap but are less complete for Go; CodeQL for Go is heavier for a small, standard-library-only server.
- **MASVS:** none, server side. Feeds the registry boundary of the STRIDE dossier.

### govulncheck: known vulnerabilities in Go code and the standard library

- **Checks:** the registry server against the Go vulnerability database, reporting a vulnerability only if the code can reach the vulnerable function. Covers the Go standard library, which is the server's only dependency.
- **Job fails when:** it does not produce a valid SARIF.
- **Alternatives:** osv-scanner also reads `go.sum` but without reachability analysis, so with more noise. Both run: govulncheck for precision, osv-scanner for one view across ecosystems.
- **MASVS:** none, server side.

### staticcheck: Go correctness

- **Checks:** bugs and bad practice beyond `go vet`: ignored results, conditions always true, deprecated APIs, dead code.
- **Job fails when:** it crashes or reports a package it could not compile.
- **Alternatives:** golangci-lint bundles many linters, staticcheck included, at the cost of more configuration.
- **MASVS:** none, code quality of the server.

### Semgrep: Dart crypto layer

- **Checks:** `client/lib` and `app/lib` against hand-written rules in `.github/semgrep/dart-crypto.yaml`, which enforce the conventions of the crypto layer (`client/lib/src/crypto.dart`, `codec.dart`): no weak random, digest or cipher mode; AES-GCM built only in `crypto.dart`, where the fixed nonce rule holds; signature results never discarded; public keys decoded only through `decodePublicKey`; constant-time comparison of secret bytes; no key material in logs; decryption failures never swallowed.
- **Rules are tested:** `.github/semgrep/dart-crypto.dart` holds a `ruleid` and an `ok` case per rule, checked by `semgrep --test` before the scan.
- **Job fails when:** a rule test fails, Semgrep cannot parse a file, or one of `crypto.dart`, `identity.dart`, `address_blob.dart` was not scanned.
- **Alternatives:** CodeQL does not support Dart. No mature Dart security analyser exists.
- **Limits:** Dart support in Semgrep is experimental, and Semgrep CE matches code patterns within a file, without data flow across functions. A discarded `verifyMessage` result is caught; a stored result that is never checked is not. **Dart coverage is exactly these rules.** Behaviour such as "a forged message is never stored" is proven by tests, not by this scan.
- **MASVS:** CRYPTO-1 (eight rules), STORAGE-2 (key material in logs).

### osv-scanner: known vulnerabilities in every dependency

- **Checks:** `client/pubspec.lock`, `app/pubspec.lock`, `registry-server/go.sum` when the server has dependencies, and any `Package.resolved`, against the OSV database. Lockfiles give exact versions, transitive ones included.
- **Job fails when:** a Dart lockfile is missing, the Go module and `go.sum` disagree, or the tool crashes.
- **Alternatives:** Dependabot alerts cover similar data but report outside code scanning; Snyk requires an account and sends the dependency graph to a third party.
- **MASVS:** CODE-3 for the app's Dart and Swift dependencies. Also the basis of the SBOM (#53).

### actionlint: GitHub Actions workflows

- **Checks:** `.github/workflows/*` for syntax and schema errors, invalid expressions, and script injection from untrusted event data. Runs shellcheck over every `run:` block.
- **Job fails when:** no workflow is found or the tool crashes.
- **Alternatives:** zizmor focuses on Actions security (permissions, injection, pinning) and could complement it.
- **MASVS:** none, CI/CD security.

### shellcheck: shell scripts

- **Checks:** every script in `.github/scripts` and `tools`, found by extension or shebang, for quoting errors, wrong tests and unhandled failures. These scripts decide whether CI passes, so a bug in them can hide findings.
- **Job fails when:** no script is found or the tool crashes.
- **Alternatives:** none comparable.
- **MASVS:** none, CI/CD security.

### CodeQL: Swift enclave plugin

- **Checks:** the Swift code with the `security-extended` queries, including taint tracking from untrusted input to sensitive operations.
- **When it runs:** only when Swift beyond the Flutter template exists (the enclave plugin of #31). A cheap Linux job decides, so the macOS runner is not started for nothing. CodeQL observes a build, so the job builds the app with `flutter build ios --debug --no-codesign`.
- **Job fails when:** the build fails or CodeQL writes no SARIF.
- **Alternatives:** Semgrep's Swift rules, without data flow.
- **MASVS:** CRYPTO-2 (enclave key handling), partly STORAGE-1 (Keychain use) and PLATFORM-1 (platform channel handler).

## Coverage

| Codebase | Own code | Dependencies |
|---|---|---|
| Registry server (Go) | gosec, staticcheck | govulncheck, osv-scanner |
| Client and app (Dart) | Semgrep, custom rules only | osv-scanner |
| Enclave plugin (Swift) | CodeQL, from #31 | osv-scanner |
| Workflows and scripts | actionlint, shellcheck | n/a |

## MASVS control → tool

To be completed as tools land (secret scanning, SBOM, binary analysis of the app). Evidence that does not come from a tool, and controls no tool covers, are tracked in the audit grid (not commited for security reasons).

| Control | Tool |
|---|---|
| CRYPTO-1 | Semgrep |
| CRYPTO-2 | CodeQL (from #31) |
| STORAGE-1 | CodeQL, partly |
| STORAGE-2 | Semgrep, partly |
| PLATFORM-1 | CodeQL, partly |
| CODE-3 | osv-scanner |
| *other controls* | none yet |
