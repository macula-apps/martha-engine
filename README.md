# martha-engine

[![CI](https://img.shields.io/github/actions/workflow/status/macula-apps/martha-engine/ci.yml?label=CI)](https://github.com/macula-apps/martha-engine/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](#license)
[![GitHub Sponsors](https://img.shields.io/badge/GitHub%20Sponsors-support-ea4aaa.svg?logo=githubsponsors&logoColor=white)](https://github.com/sponsors/rgfaber)
[![Buy Me a Coffee](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-support-ffdd00.svg?logo=buymeacoffee&logoColor=black)](https://buymeacoffee.com/rlefever)

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/macula-io/martha/main/assets/martha-full-dark.svg">
    <img src="https://raw.githubusercontent.com/macula-io/martha/main/assets/martha-full-light.svg" alt="Macula Martha" width="320">
  </picture>
</p>

<p align="center">
  <strong>A crew of coding agents that builds software the way a good team does</strong>
</p>

---

martha-engine is the agent engine that ships with standalone
[Martha](https://github.com/macula-io/martha). This repository holds the
engine; Martha itself lives in [macula-io/martha](https://github.com/macula-io/martha).

## What is Martha?

Martha gives each coding agent a job on a crew: one builds, another reviews,
and a conductor hands work from one to the next. Every hand-off, verdict and
release is written down, so you can always see who did what and why.

The crew works with one method: event storming to find the business,
vertical slices (one directory per capability), and event sourcing. Names say
what the code does.

## Two modes, one tool

| | **Solo** | **Team** |
|---|---|---|
| Who | one developer on one machine | several people, several machines |
| Needs | nothing else: no mesh, no account | the [Macula](https://github.com/macula-io/macula) mesh |
| Who may approve a push or a release | you | the people the team names |

The mode is a table of who may do what, not a different program. Solo is a
table with one person allowed to do everything; team is a table with roles.
Start solo and move to team without changing tools.

## This engine

martha-engine is built on [Goose](https://github.com/aaif-goose/goose)
(Apache-2.0). It is not Goose, and it is not endorsed by the Goose project or
its maintainers. Every change the fork makes is listed in [NOTICE](NOTICE),
one commit each on top of an upstream Goose release. For what the agent
itself can do (providers, extensions, recipes), read
[Goose's documentation](https://goose-docs.ai).

## Install

The engine ships inside standalone Martha and is installed and updated only
through `martha` (`martha update`); there is no separate install.

## Why "Martha"?

Martha was Paul McCartney's Old English sheepdog, the one in "Martha My Dear".
A sheepdog keeps a flock together and moving the same way without doing the
grazing itself. That is the job.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) and our
[Code of Conduct](CODE_OF_CONDUCT.md). To report a vulnerability, see
[SECURITY.md](SECURITY.md).

## License

Apache-2.0. See [LICENSE](LICENSE) and [NOTICE](NOTICE).
