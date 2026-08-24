# Release checklist

Complete this checklist before publishing a commit, creating a tag, or asking
the Omarchy plugin marketplace to verify a new snapshot.

## Security review

- Review the complete diff and every caller or sibling implementation affected
  by it. When a security issue is fixed in one provider, transport, or helper,
  search for the same pattern across all providers and helpers.
- Bound all data received from processes, SSH hosts, sockets, APIs, and files
  before retaining it in memory. Count raw bytes rather than JavaScript string
  characters, reject oversized input, discard partial output, and terminate the
  producer where possible.
- Bound both stdout and stderr. A limit on the expected response is incomplete
  if an error stream, log stream, line reader, or long-lived transport can still
  grow without limit.
- Apply timeouts to remote and child-process operations, and clean up their
  streams, timers, and processes on success, failure, timeout, and limit errors.
- Treat remote output and local state as untrusted input. Validate types, sizes,
  identifiers, paths, URLs, ports, and command arguments before use.
- Keep shell commands and subprocess arguments separated or strictly quoted.
  Never interpolate unvalidated values into a remote or local shell command.
- Never publish credentials, tokens, SSH keys, private remote configuration,
  runtime state, transcripts, or generated logs. Confirm ignored files remain
  excluded from the release commit.
- Document every operation that modifies the user or a remote environment,
  including installers, package managers, persistent services, and state files.
- Re-read all open marketplace security-review comments and verify each finding
  against the exact commit that will be submitted. Do not assume an automated
  baseline with no findings replaces manual review.

## Verification and publication

- Add focused regression coverage for every security fix, including rejection
  at the byte limit for each independently controlled input stream.
- Run `./scripts/test` outside the sandbox and require a clean pass.
- Confirm `git status --short` contains only intentional release changes.
- Inspect the exact release diff and commit SHA, then create and push the tag.
- Update the marketplace verification request to the exact tagged commit and
  wait for its new security baseline before requesting maintainer approval.
