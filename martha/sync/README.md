# Keeping martha-engine on upstream

This exists so Martha's engine keeps up with Goose's releases without its rebrand, its compiled-out telemetry and
self-update, or Martha's own trial lines quietly breaking (macula-io/martha#547, package S2).

**Red until S1 lands.** The fork's checks build `--bin martha-engine` and run `martha/checks/run.sh`; both come with
S1, the rebrand. Until S1 is on main, the build step fails (no `martha-engine` binary) and every check after it fails
with it, so no sync can open a pull request. S1 lands first; S2 then merges main and goes green.

## The sync job

`.github/workflows/martha-engine-sync.yml` runs daily at 04:23 UTC, or on demand for one tag:

1. **Pick** (`pick_the_upstream_tag.sh`): the newest upstream release tag `vX.Y.Z`. It is skipped when the fork's main
   already holds it, or when `sync/<tag>` is already on the origin. That branch is an earlier attempt, and a person
   finishes it there. Dispatched for that tag by name once the person has merged it there, the job skips the merge
   and goes on to the checks and the pull request.
2. **Merge** (`merge_the_upstream_tag.sh`): `sync/<tag>` is made from main and the tag is merged into it with
   `git merge`. A sync never rebases and never force-pushes. A clean merge names any workflow file upstream added.
   On a conflict the merge is undone, and the branch is pushed at main for a person to merge by hand. The job names
   the conflicted files and the fork's patches that touch them (`name_the_patch.sh`). The job pushes with
   `push_the_sync_branch.sh`; see the known limit below.
3. **Check**: upstream's own CI (`ci.yml`, dispatched on the branch) and the fork's checks
   (`martha-engine-checks.yml`) run on the sync branch.
4. **Pull request**: only when both pass, a pull request goes from `sync/<tag>` into main. Main moves only when that
   pull request lands, like every other change to main. A red check stops the job on the branch instead, and
   `name_the_patch.sh` names the fork's patches among the files the merge changed.

A patch is a commit the fork's main holds that neither the upstream tag nor upstream's main holds. The fork's main
sits on upstream's main, and a release tag is cut on a release branch, so upstream's main has commits the tag
lacks. Those commits are upstream's, not patches.

The job needs one repository setting it does not have today: Actions must be allowed to create pull requests
(Settings → Actions → General → "Allow GitHub Actions to create and approve pull requests"). A pull request opened
with `GITHUB_TOKEN` starts no workflow, which is why the job dispatches upstream's CI itself before it opens one.

### Known limit: a release that changes upstream's workflows

The job pushes with `GITHUB_TOKEN`, and GitHub refuses any `GITHUB_TOKEN` push whose commits change
`.github/workflows` (no workflow-level permission grants `workflows: write`). Upstream changes its workflows in some
releases, so the job cannot push those merges. When GitHub refuses, `push_the_sync_branch.sh` pushes `sync/<tag>`
at main instead, exactly as for a conflict, so the next daily run skips that tag rather than failing on it again,
and the run's summary prints the manual path: a person with a token that may write workflows merges the tag on
that branch, pushes it, and runs `gh workflow run martha-engine-sync.yml -f tag=<tag>`, which checks the branch and
opens the pull request. Removing the limit takes a token with `contents` and `workflows` write, such as a GitHub App's,
which is an owner's act and is not part of this package.

## The fork's checks

`.github/workflows/martha-engine-checks.yml` runs on every pull request into main and on each sync branch. It builds
`martha-engine` once (`cargo build --locked -p goose-cli --bin martha-engine --no-default-features --features
portable-default`, the build the #541 trial ran) and then runs the checks below. A job beside it fails while any
workflow other than the fork's own (`FORK_WORKFLOWS` in `pins.env`) is active on the repository
(`only_the_forks_workflows_are_active.sh`).

| Check | What it proves | From |
|---|---|---|
| `martha/checks/run.sh` | The rebrand is intact (binary, folders, the names users see, licence notices), and telemetry and self-update are compiled out of the binary and the feature lists | S1 |
| The trial lines (`run_the_trial_lines.sh`) | Lines 1-9 of the #541 trial pass on this engine, run by Martha's own driver at the pinned `MARTHA_SHA` against the pinned local model (`serve_the_trial_model.sh`) | S2 |
| No capture traffic (`watch_for_the_capture_host.sh`) | While the trial lines run, the runner never looks up PostHog's capture host. The host is read from `crates/goose/src/posthog.rs`. A control lookup must appear in the recording, so a recording that saw nothing fails | S2 |

Each trial line is one launch, stopped at the owner's ten minutes (`TRIAL_MINUTES_PER_LAUNCH`). Every line launches
once, inside the two launches a check may use. Each line's `result.json` and strace are kept as the run's
`trial-evidence` artifact for 14 days.

Every pinned value (upstream, the Martha commit, the fork's workflows, the Ollama build and its checksum, the model and
its digest) is in `pins.env`, and only there. The Node line is the one Martha's `package.json` declares, read from the
pinned checkout.

## What one sync run costs

All of it runs on GitHub's hosted runners, which are free for a public repository. These are runner-minutes, from
measurements on a 4-core box with no GPU, like a hosted runner:

| Part | Runner-minutes | Measured from |
|---|---|---|
| A daily run with nothing to sync | about 1 | a partial clone and two `git ls-remote` calls |
| Merge | about 2 | a partial clone of the fork (`filter: blob:none`), one tag fetched |
| The fork's checks | about 25 | a cold build took 3 min 55 s on that 4-core box (the fork's main at upstream `3da5adff4`, before S1, so `--bin goose`; same crates), so allow 8-10 on a runner; Ollama and the 3 GB model, 2-3; the nine trial lines, 8 min 22 s in the #541 record; S1's checks, about 2 |
| Upstream's CI | about 117, plus about 18 for the job waiting on it | the fork's own dispatched run of `ci.yml` (2026-11-17): 26 jobs, 17 minutes from start to finish |
| Opening the pull request | under 1 | |
| **One sync with something to merge** | **about 160, about 45 minutes from start to finish** | |

## Workflows on the fork

Only the fork's own workflows run on it: `martha-engine-sync.yml`, `martha-engine-checks.yml`, and upstream's
`ci.yml`, which is read-only and is how the sync job runs upstream's tests. Every other upstream workflow is turned
off before any pull request into the fork's main is opened, and the fork's checks fail while one is active. Each later sync names any workflow it adds, to turn off before it lands.
These are the ones that publish or write when main moves, a tag is pushed, or a pull request is opened:

| Workflow | Fires on | What it does |
|---|---|---|
| `canary.yml` | push to main | Builds the CLI and bundles, attests them, and creates or updates the GitHub release "Canary" |
| `publish-docker.yml` | push to main; tags `v*.*.*`, `v*.*.*-*` | Pushes an image to ghcr.io with attestations |
| `publish-ask-ai-bot.yml` | push to main (crates/, ui/, docs, ...) | Pushes a package (`packages: write`) |
| `deploy-docs-and-extensions.yml` | push to main (documentation/); after other runs | Deploys GitHub Pages |
| `gdk-release-pr.yml` | push to main (GDK crates, Cargo.lock) | Opens release pull requests |
| `release.yml` | tags `v1.*`; `release/*` branches | Builds and attests a full release |
| `release-branches.yml`, `close-release-pr-on-tag.yaml`, `gdk-release.yml` | `release/**` pushes; `v*` and `gdk-v*` tags | Release pull requests; publishes the GDK crates |
| `publish-npm.yml`, `goose-release-notes.yml`, `build-notify.yml` | after other runs | Publish npm packages; post release notes and status to Discord |
| `docs-update-gdk-api.yml` | a published release | Opens a pull request |
| `dependabot-auto-merge.yml` | pull_request_target | Merges Dependabot's pull requests into main, which moves main with no review |
| `create-release-branch.yaml`, `check-release-pr.yaml`, `update-release-pr.yaml`, `quarantine.yml`, `pr-website-preview.yml`, `take.yml` | pull requests, comments | Release branches, labels, comments, Cloudflare previews |
| `pr-smoke-test.yml` | push to main; pull requests | Runs against model providers with keys the fork does not hold |
| `mcp-conformance.yml`, `cargo-machete.yml`, `buzz-automation.yml` | push to main or any branch; pull requests | Read-only checks |
| `minor-release.yaml`, `scorecard.yml`, `stale.yml`, `cargo-deny.yml`, `model-toolcall-conformance.yml`, `update-health-dashboard.yml` | schedules (and push to main for the first two) | Release branches, scorecard upload, closing stale issues. GitHub keeps scheduled workflows off on a fork (`disabled_fork`) until someone turns them on |
| `build-acp.yml`, `build-cli-linux.yml`, `bundle-macos.yml`, `bundle-windows.yml`, `create-version-bump-pr.yaml`, `maven-sdk.yml`, `python-sdk-wheels.yml`, `patch-release.yaml` | only when called or dispatched | Building blocks of the release workflows |

Dependabot's own version updates (`.github/dependabot.yml`) open pull requests on the fork too. They are a
repository setting, not a workflow.
