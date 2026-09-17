# Security policy

## Reporting

Please report suspected vulnerabilities through
[GitHub private vulnerability reporting](https://github.com/tmarhguy/tomato/security/advisories/new).
Do not include secrets, private device identifiers, or exploit details in a
public issue.

If private reporting is unavailable, open a public issue containing only a
request for a private contact channel.

## Scope and support

Tomato is an experimental computer project, not a safety-critical or hardened
platform. Security reports are welcome for repository tooling, the browser
emulator/site, FPGA interfaces, and accidental secret or private-artifact
exposure. No released version currently carries a fixed security-support
lifetime.

The public website security contact is mirrored at
[`web/.well-known/security.txt`](web/.well-known/security.txt). A source-level
fix is not proof that a public site, programmed FPGA, or external Envelop
deployment has received that fix.
