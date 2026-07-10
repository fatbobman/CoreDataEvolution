# Security Policy

CoreDataEvolution is a Swift package for Core Data macros, typed paths, actor isolation, and
tooling. It does not include networking, authentication, encryption, or server-side components, but
security-sensitive defects can still exist in generated code, tooling behavior, or documentation.

## Supported Scope

Please use this policy for issues that could affect users' data integrity, build pipeline safety, or
the safe use of generated Core Data code.

Good examples include:

- generated code that can silently corrupt or misroute persisted values
- tooling behavior that writes outside the intended output location
- unsafe defaults in serialization, transformable values, or generated accessors
- documentation that would lead users toward an unsafe migration or deployment practice

General bugs, feature requests, and documentation clarifications should use the public issue
templates instead.

## Reporting a Vulnerability

If GitHub private vulnerability reporting is available for this repository, use the repository's
Security tab and choose "Report a vulnerability."

If private vulnerability reporting is not available, open a public issue with only a brief,
non-sensitive summary and ask for a private follow-up path. Do not include exploit details, private
data, proof-of-concept payloads, or undisclosed project information in a public issue.

When reporting, include:

- affected CoreDataEvolution version or commit
- Swift and Xcode versions
- platform and deployment target
- the affected package area, such as macros, actor isolation, typed paths, Observation, or
  `cde-tool`
- a concise impact description
- any safe, non-sensitive reproduction details

## Handling Principles

The maintainer will review security reports as availability allows. This project does not promise a
fixed response-time SLA, but security reports are treated separately from routine bug reports.

Accepted fixes should include appropriate tests or validation notes where practical. If public
disclosure is needed, coordinate timing with the maintainer before posting full details publicly.
