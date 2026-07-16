## 2026-07-11

### Additions and New Features

- TypeScript overlay: added a consumer-owned `playwright.config.ts` seed with `testIgnore`
  coverage for `_temp*` scratch names and `dist_*/` private lane-build directories.

### Fixes and Maintenance

- `devel/bump_version.py`: added Rust metadata support. The utility now discovers and updates
  package versions in `Cargo.toml` and matching local-package entries in `Cargo.lock`, while
  leaving dependency versions in the lockfile unchanged. `Cargo.toml` and `pyproject.toml`
  version discovery now shares one TOML parser.
- Scratch collector contract: preserved the canonical ESLint exclusions for `_temp*` and
  `dist_*/`, extended `.prettierignore` and the TypeScript gitignore to cover the same names,
  and made shared Python hygiene discovery explicitly skip those paths even if they are
  force-tracked. Kept regression coverage behavior-based with one test covering root-level and
  nested scratch paths through the public discovery helper.
- The propagated TypeScript style guide now states that every repo-wide collector owns
  exclusions for `_temp*` and `dist_*/`; gitignore alone does not keep untracked scratch
  artifacts out of directory-globbing tools. The Playwright test style guide now gives the
  required `testIgnore` setting directly. The mirrored `docs/CLAUDE_HOOK_USAGE_GUIDE.md`
  remains unchanged; its source text is owned by the `claude-code-permissions-hook` repo.

## 2026-07-10

### Additions and New Features

- `templates/swift/docs/LIQUID_GLASS.md`: added `## 7. Design toolbars and menus for glass`
  covering the macOS 27 (Golden Gate) Liquid Glass retuning: the uniform frosted toolbar
  replacing macOS 26's floating separated controls, standardized window corner radius,
  edge-to-edge sidebars, the system-wide transparency slider (ultra clear to fully tinted),
  and stronger diffusion with darkened edges and brighter specular highlights (MacRumors
  reference added). Core guidance: system chrome belongs to the system -- build toolbars with
  standard `.toolbar`/`ToolbarItem` and menus with standard `Menu`/`commands` APIs so each
  year's retuning applies automatically; keep custom `.glassEffect` out of the toolbar band
  and menu bar; treat translucency as a user-controlled range; record OS version in evidence
  captures. Renumbered sections 7-13 to 8-14, updated the TOC, intro references, the dispatch
  brief (captures now labeled with OS version), and the compact rule set. Follow-up: reworked
  the section 7 toolbar guidance from an API listing into best practices (toolbar quality is
  best-practices work, not API work): grouping is meaning (`ToolbarSpacer` fixed splits
  semantic clusters, flexible pushes groups apart; navigation together, confirmatory actions
  apart; overflow to menus), symbols first built as `Label`s with icon-versus-text consistency,
  placement drives prominence (`ToolbarItemPlacement`, at most one tinted action via
  `.buttonStyle(.glassProminent)`, trust defaults), and `.scrollEdgeEffectStyle(_:for:)`
  (`.hard` over dense data, `.soft` immersive) for where content meets the bar; pointed at
  Apple's "Landmarks: Refining the system provided Liquid Glass effect in toolbars" sample.

- `templates/swift/docs/LIQUID_GLASS.md`: added two sections on the subtle gotchas of getting
  Liquid Glass demonstrably correct. `## 10. Verify the glass with visual evidence` documents
  why screenshots can lie (offscreen/cached render paths such as `cacheDisplay(in:to:)`,
  `bitmapImageRepForCachingDisplay(in:)`, and `ImageRenderer` may skip live backdrop
  compositing, so glass captures come out flat gray even when the on-screen app is correct;
  empty white backdrops give glass nothing to sample) and prescribes an evidence protocol:
  colorful content under the glass edges, live on-screen capture, a Reduce Transparency
  differential capture proving the effect responds to system state, a `.regularMaterial`
  side-by-side control, scrolling-backdrop captures, and per-capture appearance-mode labeling.
  Includes a flat-glass checklist (SDK/`#available` branch, `UIDesignRequiresCompatibility`,
  Reduce Transparency setting, backdrop contrast, opaque `.background(...)` in the sampling
  path, capture path). `## 11. Subtle gotchas: layers and colors` covers z-order (glass above
  real content), no glass on glass, opaque backgrounds blocking sampling,
  `GlassEffectContainer`/`glassEffectID` grouping, the capsule default shape, luminance-driven
  light/dark switching (use semantic foreground styles), `.tint(...)` modulating rather than
  painting, mid-tone multi-color test backdrops, and `.interactive()` on custom controls, plus
  a minimal `GlassEvidenceView` gradient harness for evidence captures, and a note that glass
  self-adjusts opacity with the backdrop (more opaque over busy content, more transparent over
  plain backgrounds), so cross-backdrop variation is expected behavior, not a rendering bug.
  Added `## 12. Guarantee contrast over glass`: glass guarantees no minimum text contrast (the
  backdrop is user-controlled), so contrast must come from layered fixes -- honor
  `accessibilityReduceTransparency` (opaque fill swap;
  `NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency` on AppKit paths), honor
  `colorSchemeContrast == .increased` (full-alpha semantic labels, no custom tints), a 40
  percent black scrim under white text as a contrast floor, vibrancy for secondary labels only,
  judging contrast over near-white/bright-photo/mid-tone-gradient backdrops, and auditing
  captures with a contrast checker (below 4.5:1 normal text or 3:1 large text is a bug).
  Renumbered the compact rule set to `## 13` and extended it with three verification and
  contrast bullets; added the "Applying Liquid Glass to custom views" reference. Capture-path
  and differential-proof hazards were first identified during `SwiftlyCodeEdit` WP-G2
  hardening, then encoded upstream here. Added a purpose line (the doc helps a manager get
  Liquid Glass right) and a task-grouped table of contents with anchor links: design sections
  1-9 (read before dispatching UI work), verification sections 10-12 (read before accepting
  screenshots as evidence, with one-line hooks per section), and the section 13 summary.

- `templates/swift/docs/LIQUID_GLASS.md`: made layer and contrast correctness more obvious to
  managers and coders. Section 10 gains a "What correct glass looks like" expected-appearance
  matrix (backdrop x correct appearance: nearly invisible over plain white/black is expected,
  mid-tone gradient is the best judging backdrop, busy content raises the material's own
  opacity, Reduce Transparency yields the flat differential-proof fill) with the note that a
  capture can only prove glass over the two contrast-bearing backdrops, plus a "Paste-able
  evidence brief for dispatch" code block managers copy verbatim into subagent briefs (four
  required captures and explicit SHIP/REWORK criteria). Section 11 gains an ASCII
  sampling-path diagram (vibrant label over glass over a clear gap over content) showing where
  an opaque `.background(...)` blocks sampling. TOC hook for section 10 updated.

### Behavior or Interface Changes

- `templates/swift/docs/LIQUID_GLASS.md`: reframed the doc SwiftUI-first with AppKit treated
  as deprecated. Retitled section 8 from "Keep AppKit bridges visually owned" to "Treat AppKit
  bridges as legacy escape hatches": SwiftUI is the implementation layer for all new UI
  including every glass surface; an AppKit bridge is reached only when SwiftUI cannot yet
  express the behavior, kept narrow, and planned for removal. Updated the intro, section 1
  (build all new UI with standard SwiftUI components), the section 12
  `NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency` note (now labeled a legacy
  AppKit bridge check), the compact rule set bullets, and the TOC anchor to match.

## 2026-07-09

### Fixes and Maintenance

- `devel/clean_build.sh`: fixed the Swift section of the light clean, which previously deleted
  `.build` wholesale, wiping SwiftPM's fetched dependency checkouts (`.build/checkouts`,
  `.build/repositories`, `.build/registry`) and `.build/workspace-state.json` and forcing a
  re-fetch on the next build. Replaced with targeted deletions of compiled output only
  (`.build/debug`, `.build/release`, `.build/artifacts`, `.build/build.db`, `*-apple-macosx`
  triple directories, top-level `.build/*.yaml` build plans), so the light clean now mirrors
  `swift package clean` (recompile only) instead of `swift package reset` (full re-fetch).
  Dropped the light clean's `delete_path .swiftpm` (per-user/IDE state, not build output);
  `dist_clean.sh` still removes it for a full reset. First identified and verified in the
  `SwiftlyCodeEdit` consumer repo, then ported upstream here so propagation does not
  reintroduce the bug.
- `devel/dist_clean.sh`: added the `swift: dependencies re-fetch automatically on next build`
  line to the header's post-clean reinstall-note block, matching the existing per-language
  notes for typescript, python, and rust.

## 2026-07-05

### Behavior or Interface Changes

- `docs/PYTEST_STYLE.md`: rewrote the `## Fixture policy` section into an inline-first policy
  with a closed three-case durable allowlist (`tmp_path`; the vendored `collect_report`
  autouse harness; using an existing committed repo file directly when that file is what the
  test checks). Added a one-sentence definition of "inline" (test input written directly in
  the test file, close to the assertion). Added a standing policy rule that a committed
  `tests/fixtures/` directory is shared test infrastructure needing explicit human sign-off
  before it is added. All instructions phrased positively per the Prompt positively
  philosophy. Added one checklist item to the "Is this a good pytest?" list pointing at the
  Fixture policy allowlist.
- `templates/typescript/docs/TYPESCRIPT_STYLE.md`, `templates/website/docs/PLAYWRIGHT_USAGE.md`,
  `meta/docs/HUMAN_GUIDANCE.md`: trimmed their fixture mentions to a bare pointer at the
  canonical Fixture policy in `docs/PYTEST_STYLE.md`, keeping `docs/PYTEST_STYLE.md` the single
  source of truth (omission over repetition).

### Removals and Deprecations

- `tests/TESTS_README.md`: removed the `tests/playwright/` tree line that advertised an
  `optional` `fixtures/` directory, so the docs stop inviting fixture creation. This supersedes
  and removes the "optional test data for loader/file-shape checks" wording added to this same
  line in the `2026-07-01` entry below; that wording is now gone from the file entirely.

### Decisions and Failures

- Coding agents overproduce fixtures; friendly "when a fixture is OK" prose read as an
  invitation, and on-disk `tests/fixtures/` directories accumulated stale files. Reshaping the
  policy into an inline-default closed allowlist, plus trimming satellite mentions across
  overlay docs, is meant to make the docs resist fixture creation by default. The design goal
  is "inline first, with durable exceptions," not "fixtures are forbidden."

## 2026-07-04

### Additions and New Features

- `meta/propagation/manifests.yaml`, `repolib/manifests.py`, `repolib/model.py`:
  `REPO_TYPE` becomes a single-token inheritance DAG. Added three new base
  types (`scripted`, `website`, `compiled`, all directly usable markers) to
  `known_repo_types`, plus a `repo_type_inherits` section
  (`python->scripted`, `rust->compiled`, `swift->compiled`,
  `typescript->website`); `scripted`, `website`, `compiled`, and `other` are
  roots. `repolib.manifests` validates every parent is a known token and the
  graph is acyclic at load time. `repolib.model` adds `REPO_TYPE_PARENTS`,
  `ancestors(repo_type)`, and `effective_type_chain(repo_type)` (returns
  `[repo_type, *ancestors]` nearest-first) as the one canonical expansion
  helper; `select_overlay_dirs`, `overlay_roots_for_type`, and
  `shared_rule_ships_to` all consume it, so a repo receives its own overlay
  plus every ancestor's overlay, unioned, and a rule ships whenever the
  effective chain intersects `rule['repo_types']`.
- `tests/meta/test_repo_type_inheritance.py` (new): pins
  `ancestors`/`effective_type_chain` ordering, cycle and unknown-parent
  raises, a disjointness guard (fails if two overlays in one chain name the
  same `file_rel`), ancestor-conditional inheritance via a synthetic
  manifest, and a routing matrix across all eight tokens asserting presence
  or absence of `docs/PLAYWRIGHT_TEST_STYLE.md`, `tsconfig.json`, and
  `devel/make_release.py`.
- `tools/detect_repo_type.py`: detects `website` (high confidence) from a
  root `mkdocs.yml`, counted in the `strong_signals` mixed-marker check so
  `mkdocs.yml` alongside a language marker reports `ambiguous`. An
  `index.html`-only tree stays `ambiguous`; `website` remains a manual
  marker, avoiding misclassifying static exports or generated docs.
- `repolib/repo.py`, `reset_repo.py`: `parse_repo_type_choice`, the interview
  prompts, `normalize_project_type`, and `SCAFFOLD_SENTINELS` now recognize
  the three base types by full name (sentinel for `website` is
  `mkdocs.yml`).
- `templates/shared/docs/PLAYWRIGHT_TEST_STYLE.md`: new browser test authoring
  style guide, originally routed via a shared overlay to
  `repo_types: [typescript, other]` so it reached every repo that serves HTML
  (typescript games and MkDocs-Material sites) without shipping to pure CLI
  repos. Prescriptive, positive-voice house rules grounded in a survey of ~97
  Playwright files across 12 repos: two execution models (runner
  `@playwright/test` default for configured app tests, bare-library `.mjs`
  first-class for config-less MkDocs/survey/screenshot workflows), file layout
  under `tests/playwright/`, load-over-HTTP as the central rule,
  accessible-first then `data-*` selector priority, web-first waits and real
  visible clicks, per-model pass/fail signaling, `addInitScript` setup idioms,
  headless Chromium with `test-results/` screenshots, one compact pitfalls
  table, and two small copyable runner and `.mjs` examples. Superseded later
  the same day by the `templates/website/` overlay move recorded below.

### Behavior or Interface Changes

- `meta/propagation/manifests.yaml`: `source_release` (the former
  `html_playwright_style`-style hand list `[rust, swift, python, other]`)
  now targets the base set `[scripted, compiled, other]`, so any future
  scripted or compiled language inherits GitHub-source-release tooling
  (`devel/make_release.py`) with no further manifest edit. `website` and
  `typescript` stay out because a docs or game site publishes builds, not
  source releases.
- `repolib/files.py` `auto_discover_test_files`: now derives its
  overlay/root decision from `effective_type_chain(repo_type)`, so an
  inheriting type (for example `typescript`) also discovers its ancestor's
  (`website`) template tests.
- `docs/REPO_STYLE.md`, `docs/E2E_TESTS.md`, `docs/PYTEST_STYLE.md`: prose
  updated to describe the base types, the inheritance DAG, base-targeted
  routing (citing `source_release`), and `PLAYWRIGHT_TEST_STYLE.md` shipping
  through the `templates/website/` overlay to the website family (`website`
  plus its inheriting `typescript`), replacing the old `[typescript, other]`
  hand-list phrasing.

### Removals and Deprecations

- Retired the `html_playwright_style` shared-overlays rule
  (`meta/propagation/manifests.yaml`), which had targeted `repo_types:
  [typescript, other]`. `git mv templates/shared/docs/PLAYWRIGHT_TEST_STYLE.md
  templates/website/docs/PLAYWRIGHT_TEST_STYLE.md` plus three web-general
  assets moved from `templates/typescript/` to `templates/website/`
  (`docs/PLAYWRIGHT_USAGE.md`, `tests/playwright/repo_root.mjs`,
  `devel/setup_playwright.sh`); `typescript` now receives all four through
  ordinary folder-location overlay routing (inheriting `website`) instead of
  a hand-maintained shared-overlay rule. The TS-only toolchain
  (`tsconfig*`, `eslint*`, `.prettier*`, `docs/TYPESCRIPT_STYLE.md`, build
  and test-naming scripts) stays in `templates/typescript/`.

### Fixes and Maintenance

- `README.md`: repointed both `PLAYWRIGHT_USAGE.md` links to their new
  location, `templates/website/docs/PLAYWRIGHT_USAGE.md`, after the file
  move above.
- Cross-overlay doc references converted to backticked names:
  `templates/typescript/docs/TYPESCRIPT_STYLE.md`,
  `templates/typescript/tests/TESTS_TYPESCRIPT_README.md`, and
  `templates/website/docs/PLAYWRIGHT_TEST_STYLE.md` referenced docs shipping
  from a different overlay (or the universal `docs/` tree) via bare markdown
  links (for example `[PLAYWRIGHT_USAGE.md](PLAYWRIGHT_USAGE.md)`) that
  resolve only after propagation flattens the overlays into one consumer
  `docs/` folder. No single relative link is valid both in the split
  template tree and in the propagated consumer, so these now use the
  repo's existing backticked-name convention for cross-overlay references
  (matching the pre-existing `PLAYWRIGHT_USAGE.md` mention in the same
  doc). A first attempt excluded the three files via a populated
  `REPO_HYGIENE_FILTERS["markdown_links"]` registry in `tests/conftest.py`;
  that was reverted because `merge_conftest` ships the template's registry
  block to freshly bootstrapped consumers, which would have baked
  template-only glob paths into every new repo. The registry stays `{}`.
- `tests/file_utils.py`: `_load_repo_hygiene_filters()` now loads
  `REPO_HYGIENE_FILTERS` from the explicit `tests/conftest.py` path anchored
  at the repo root, replacing the module-name conftest import. The old
  `importlib.import_module("conftest")` resolved to whichever `conftest.py`
  pytest imported first; under full-suite collection order a same-basename
  `tests/meta/conftest.py` (it sorts before `test_*`) could win
  `sys.modules["conftest"]`, lack the attribute, and silently return an
  empty Layer-2 registry. Latent until a registry entry exists, but a real
  shadowing bug worth fixing while it was visible. Also dropped the now
  redundant bare `import importlib` left behind by the rewrite.
- `meta/docs/PROPAGATION_RULES.md`: refreshed the stale `source_release`
  worked example (old `[rust, swift, python, other]` hand list) to the
  base-targeted `[scripted, compiled, other]` shape, added a
  "Repo type inheritance" section documenting the `repo_type_inherits`
  DAG and chain-based routing, and added a `templates/website/` row to
  the folder-convention table.
- `tests/meta/conftest.py`: module docstring now carries a DUAL-CONFTEST MAP
  documenting the two conftest roles -- `tests/conftest.py` is the shipping
  merge seed (must hold no repo-specific data; `REPO_HYGIENE_FILTERS` stays
  `{}`) while `tests/meta/conftest.py` is template-meta and never ships --
  plus the shadowing history, so a future maintainer does not repeat the
  populated-registry mistake.

### Decisions and Failures

- `pypi` stays a `has_file` conditional overlay under `python` rather than
  becoming its own marker token; auto-gating by `pyproject.toml` already
  works and promoting it adds no capability.
- `templates/swift/` is left unopened in this change; folder-location
  routing picks up a swift overlay automatically the moment one exists, so
  no swift overlay was scaffolded.
- No MkDocs consumer was checked out to validate the `website` family
  against `source_release` exclusion in practice; the design rule (docs and
  game sites publish builds, not source releases) is a one-line manifest
  change to reverse if a real MkDocs consumer needs it.
- Earlier the same day, routing had chosen a shared overlay to
  `[typescript, other]` over a universal `docs/` drop, reasoning there was no
  `web` repo_type token so web-serving repos had to be targeted by
  enumerating the typescript and `other` families (consequence: the doc
  reached every `other` repo, and MkDocs consumers needed a
  `REPO_TYPE=other` marker). The base-type inheritance DAG recorded above
  replaces that hand list: `website` is now the token, and `other` no
  longer needs to carry it.
- The confirmed MkDocs consumer (`biology-problems-website`) runs Playwright as
  bare-library `.mjs` scripts with no `playwright.config.ts`, so the doc keeps the
  bare-library model first-class rather than assuming the `@playwright/test`
  runner everywhere. Generalizing `run_playwright_tests.sh` to a shared runner was
  left out of scope: its `dist/`+`build_github_pages.sh` build gate is
  game-specific and the MkDocs consumer would first need to adopt a config runner.

## 2026-07-03

### Additions and New Features

- `docs/REPO_STYLE.md`: added a `### source_me.sh contract` subsection under
  Scripts and executables. Documents that `source_me.sh` is bash-only and a
  NOEXIST/consumer-owned seed (local edits do not propagate back), states the
  bashrc-first ordering invariant (`~/.bashrc` clears `PYTHONPATH`, so any
  `PYTHONPATH` line comes after it), records the decision to keep `PYTHONPATH`
  out of the seed and ship one generic seed for all repo types (no
  repo_type-specific seeds), and gives the one canonical guarded `PYTHONPATH`
  extension idiom plus when to enable it. Backed by a `~/nsh`-wide survey of 44
  `source_me.sh` files: ~34 need no `PYTHONPATH`, and the ~7 that do each need a
  different target, so no universal line fits and the need does not track repo
  type.
- `tests/meta/test_source_me_seed.py`: new template-local test pinning the seed
  invariant. Sources `source_me.sh` in a subprocess and asserts `PYTHONPATH` is
  empty (the repo-root extension ships commented) while `PYTHONUNBUFFERED` and
  `PYTHONDONTWRITEBYTECODE` are `1`. Lives under `tests/meta/`, which the
  propagation walk skips (`skip_walk_dirs` includes `meta`), so it does not ship
  to consumers. Guards against ever shipping an active `PYTHONPATH` line.

### Behavior or Interface Changes

- `meta/propagation/manifests.yaml`: dropped the `when: lacks_file` /
  `path: pyproject.toml` condition from the `source_release` shared-overlay rule.
  `make_release.py` (source zip/tgz release) now ships unconditionally to
  python (INCLUDING PyPI python repos), rust, swift, and other -- typescript
  stays excluded because those repos are GitHub Pages based and do not cut
  releases. A PyPI python repo now carries both `make_release.py` (source
  snapshot, overwrite bucket -- vendored, overwritten each sync) and its `_pypi`
  `submit_to_pypi.py`. Updated `tests/meta/test_shared_overlays.py` and
  `meta/docs/PROPAGATION_RULES.md` to match. Kept `make_release.py` in
  `shared_overlays` rather than universalizing it: routing to a SUBSET of types
  (all but typescript) is exactly what shared overlays are for.
- `meta/propagation/manifests.yaml`: added a header note stating when a file
  belongs in this manifest -- only when folder LOCATION cannot express its
  routing fate (subset-of-types, never-ship, root files, merge). Universal files
  go in `devel/`/`docs/`/`tests/`, single-type files under `templates/<type>/`;
  do not register a filename here that a folder already routes.
- `source_me.sh`: rewrote the comments and added a commented, canonical
  repo-root `PYTHONPATH` extension block (disabled by default). No active
  runtime behavior change -- the bash guard, bashrc-first ordering, and both
  `PYTHON*` exports are unchanged, and nothing new executes at source time. The
  comments now state the bashrc-first ordering invariant and when to uncomment
  the extension.
- Added `all` as a recognized `REPO_TYPE` token for repos that consume every template family. `all`
  now appears in the repo-type manifest, the reset/bootstrap prompt, and the style docs. Routing for
  `all` aggregates the propagation plan for the existing typed repos so it receives universal files
  plus every typed overlay.

### Fixes and Maintenance

- `repolib/model.py`: taught the lower-level `find_source_for_bucket` resolver to
  handle `repo_type='all'` by fanning out across every concrete type and
  returning the first match. Previously only the propagation runner
  (`process.py`) knew this, so real `all` propagation worked but the model-level
  resolver returned None for a file living in a concrete family (for example
  `templates/typescript/check_codebase.sh`). The `all` resolution semantic now
  lives in one place, shared by the runner and any direct resolver caller. This
  gap was masked until the stale `Brewfile` noexist entry (below) was removed and
  `tests/meta/test_repolib_spec_resolves_to_source.py` could reach the `all` case.
- Removed stale propagation entries for files deleted as empty stubs: `Brewfile`
  from `root_propagate_allowlist` and `universal_noexist`, and
  `noexist/docs/RELEASE_HISTORY.md` + `noexist/docs/NEWS.md` from the
  `source_release` shared-overlay rule in `meta/propagation/manifests.yaml`.
  Python repos still receive their real `templates/python/noexist/Brewfile`
  (Homebrew python@3.12) via the typed route. Also removed the now-empty
  `templates/shared/noexist/` directory. Folder-based routing ships what exists
  on disk; the manifest must not list deleted sources.
- `tests/meta/test_shared_overlays.py`: removed `test_rule_path_exists_on_disk`,
  a test whose whole body was an `os.path.isfile` existence check over the
  manifest's listed paths. A bare file-exists assertion contradicts the
  folder-based propagation model and breaks whenever a seed is legitimately
  deleted. The disk->manifest coverage guard (orphan shared files raise) and the
  behavioral shipping-logic tests remain.
- Fixed `all` propagation so bucket source lookup resolves across every concrete repo type instead
  of failing with missing-source errors when a file lives in a different family. `all` now expands
  across every concrete repo type in `REPO_TYPE_ORDER`, so propagation fans out across the full
  family set rather than treating `all` as a scalar token.
- Clarified that `Brewfile`, `docs/NEWS.md`, and `docs/RELEASE_HISTORY.md` are propagated because
  they are `noexist` targets, not because they are empty. Local deletion alone does not change the
  propagation rule.
- `templates/typescript/docs/FUN_VIBES_DESIGN_STYLE.md`,
  `templates/typescript/docs/PLAYFUL_TRAINING_GAME_STYLE.md`: fixed broken markdown links flagged by
  `tests/test_markdown_links.py`. Removed the dead `docs/GAME_USAGE.md` link (non-universal file that
  ships nowhere). Converted the `docs/REPO_STYLE.md` and `docs/MARKDOWN_STYLE.md` references from
  markdown links to backticked plain paths: those universal docs land flat in a consumer `docs/`, so
  a bare-sibling link is correct in consumers but unresolvable in the template tree where these files
  sit under `templates/typescript/docs/`. Plain-path text reads correctly in both layouts. Co-located
  sibling links (FUN_VIBES <-> PLAYFUL, PLAYWRIGHT_USAGE) stay as markdown links since they resolve in
  both places. `tests/test_markdown_links.py` now passes (36 files).

### Behavior or Interface Changes

- `docs/COLOR_CONTRAST_ACCESSIBILITY.md`: reframed as the generic WCAG contrast method doc (the
  canonical propagation source shipped to consumer repos) -- target ratio, contrast-ratio formula,
  calculator usage, online checkers, and the applicable rules. App-specific audited palette tables
  no longer live here; each consumer repo carries its own palette audit in a separate
  `docs/PALETTE_CONTRAST_AUDIT.md`.

## 2026-07-02

### Additions and New Features

- `devel/clean_build.sh`: new light build cleaner. Wipes build output, tool caches, and test
  artifacts (dist, _site, `*.tsbuildinfo`, .eslintcache, test-results, playwright-report,
  coverage, Python bytecode) while KEEPING dependency installs (node_modules, Rust target/) so
  the next build starts ab initio with no reinstall. In TypeScript repos this is the target of
  `npm run clean`. Ships universally via `devel/`.

### Behavior or Interface Changes

- `devel/dist_clean.sh`: reframed as the deep "restore to shippable state" cleaner (fresh-clone
  equivalent for a source release). It still removes node_modules and Rust target/, but no longer
  deletes `package-lock.json` -- the lockfile is committed and drives reproducible `npm ci`, so it
  belongs in a distribution. Header now points everyday build cleaning at `devel/clean_build.sh`.

### Removals and Deprecations

- `meta/propagation/manifests.yaml`: removed `dist_clean.sh` from `root_propagate_allowlist`. Both
  cleaners now live in `devel/` (universal propagation); no cleaner ships to the repo root.

## 2026-07-01

### Additions and New Features

- `docs/PYTEST_STYLE.md`: added a canonical `## Fixture policy` section. Setup is inline first:
  tests keep setup inline and close to the test, and use real repo files when the real file is
  the point. Separate test data or shared setup is reserved for cases where file shape, loader
  behavior, or shared test infrastructure is the thing under test. The policy covers both
  on-disk `tests/fixtures/` files and custom `@pytest.fixture` functions. `tmp_path` and the
  vendored `collect_report` autouse harness (at the canonical hygiene module shape) are named
  as the durable examples of shared infrastructure.

- `meta/docs/HUMAN_GUIDANCE.md`: recorded the fixture policy as intentional durable human
  guidance, a four-bullet entry pointing to the canonical section in
  `docs/PYTEST_STYLE.md`. Reworded "synthetic fixtures" / "fixture repos" to
  "synthetic repo trees" for consistency with the new policy language.

### Behavior or Interface Changes

- `docs/PYTEST_STYLE.md`: removed pro-fixture guidance ("Prefer fixtures for setup and shared
  resources", "fine and preferred for setup"). Test-structure bullets now read "Keep setup
  inline and close to the test." and "Use `tmp_path` for temp files." The "Is this a good
  pytest?" checklist no longer carries a fixture item; fixture nuance lives only in the new
  policy section.

- `templates/typescript/docs/TYPESCRIPT_STYLE.md`: reduced the "Node test fixture policy" to a
  two-paragraph inline-setup-first form with a plain-text pointer to the canonical section in
  `docs/PYTEST_STYLE.md`. Removed the fixture-creation bullets and the transitional example.

- `templates/typescript/docs/PLAYWRIGHT_USAGE.md`: removed the mention of a
  `tests/playwright/fixtures/` directory. Added one sentence separating Playwright's own
  "fixtures" framework feature from repo test-data design decisions.

- `docs/REPO_STYLE.md`: updated the `PYTEST_STYLE.md` index line to say "fixture policy".

- `tests/TESTS_README.md`: updated the `fixtures/` tree line to read "optional test data for
  loader/file-shape checks".

### Fixes and Maintenance

- `docs/CHANGELOG.md`: rotated per the changelog-rotation policy in `docs/REPO_STYLE.md`
  (file had reached 1038 lines). Moved the `2026-06-29` through `2026-06-12` day blocks into
  a new `docs/CHANGELOG-2026-06b.md` archive (next letter since `docs/CHANGELOG-2026-06a.md`
  already existed); the active file now keeps only the `2026-07-01` and `2026-06-30` blocks.
  Ran with `devel/rotate_changelog.py --dry-run` first, then `--yes`.

### Decisions and Failures

- The fixture policy covers both on-disk fixture data files and custom `@pytest.fixture`
  functions. Root cause: coding agents tend to overproduce fixtures, so the docs steer agents
  toward inline setup by default.

- This was a docs-only pass; no enforcement guard test was added. The vendored `collect_report`
  autouse harness stays as the named shared-infrastructure instance -- migrating it would be a
  separate code change across vendored tests.

- Applied an omission principle on human direction: fixture nuance lives only in the canonical
  `docs/PYTEST_STYLE.md` section; satellite docs say "inline setup first", point there, or say
  nothing, since each extra mention makes fixtures more salient to agents. Dropped "framework
  behavior" from the durable-use list as too broad; the canonical list is now "file shape,
  loader behavior, or shared test infrastructure".

### Developer Tests and Notes

- Verified with a full `pytest tests/` run: "1335 passed in 4.55s". A repo-wide categorized
  fixture-mention audit came back clean: every hit is policy text, a pointer, a durable-use
  mention, an actual path, a framework product term, or changelog history.
- `templates/typescript/docs/TYPESCRIPT_STYLE.md`: documented the `tests/**/*.{ts,mts}` ESLint
  relaxation (`@typescript-eslint/no-floating-promises` and `no-console` off for `node:test`
  files, `src/` and `tools/` stay strict) and noted `tsx` as a required canonical
  devDependency for `check_codebase.sh` step 5.

## 2026-06-30

### Additions and New Features

- `templates/typescript/docs/TYPESCRIPT_STYLE.md`: reconciled dependency-version guidance with
  evidence from ten ~/nsh/TYPESCRIPT/ repos. Replaced stale frozen numbers ("Require 5.x",
  ">=9") with an apps-not-libraries `>={latest}` policy: high floors, `>=` always, `<` only
  for a confirmed incompatibility such as the typescript-eslint TS ceiling.
  `tools/sync_typescript_package_pins.py` is the refresh helper; lockfile regenerated forward;
  post-refresh validation runs through the normal gates.

- `templates/typescript/docs/TYPESCRIPT_STYLE.md`: canonicalized the entry point. `src/main.ts`
  or `src/main.tsx` is canonical; `src/init.ts` is legacy with a migrate direction
  (`build_github_pages.sh` accepts it as a fallback and prints a rename warning).

- `templates/typescript/docs/TYPESCRIPT_STYLE.md`: documented the esbuild policy: CLI default
  for the standard build, JS API only when a plugin requires it; loaders, multi-entry, and
  pre-build codegen variants covered. Elevated a command-architecture principle: named scripts
  are the interface, npm aliases are thin 1:1 mirrors.

- `templates/typescript/docs/TYPESCRIPT_STYLE.md`: added a node-test fixture policy: inline
  durable inputs directly; use fixtures for initial scaffold or a loader under test.
  Reconciled the stale pdf "removed" note.

- `templates/typescript/docs/TYPESCRIPT_STYLE.md`: added "Live demo / GitHub Pages" section
  documenting the Actions-from-dist deploy shape (`build_github_pages.sh` -> `dist/`,
  `dist/.nojekyll`, `dist/` as site root, root-level `deploy-pages.yml` seed a human moves
  into the workflows directory). Convention framed from the science-choose-adventure precedent.
  Added a `### Pages deployment shape` subheading and the live-URL README convention
  (link as `https://<owner>.github.io/<repo>/` just below the first paragraph).

- `templates/typescript/noexist/run_playwright_tests.sh`: new consumer-owned seed giving
  Playwright its own named front door. Runs preflight, optional `--build`, builds `dist/`
  as needed, forwards args to `npx playwright test`, relies on `playwright.config.ts`
  `webServer`. Not part of `check_codebase.sh`. Includes a bash 3.2-safe empty-array guard
  on the run line.

- `templates/typescript/tests/TESTS_TYPESCRIPT_README.md`: fully rewritten as a
  consumer-facing onboarding quickstart aimed at a new repo manager. Covers front-door
  scripts (`check_codebase.sh`, `run_playwright_tests.sh`), repo layout under `tests/`,
  four test tiers and their run order (pyflakes -> node --test -> Playwright -> E2E),
  ship-to-Pages workflow with the live-URL README convention, and common first-run
  failures. Removes template-internal history and overlay framing (the 2026-05-24
  removed-mirrors narrative, `propagate_style_guides.py`/overlay language, "vendored
  Python tests in this overlay"). The corrected Playwright front-door instruction
  pointing to `./run_playwright_tests.sh` is part of this rewrite.

### Behavior or Interface Changes

- `templates/typescript/noexist/package.json`: re-pointed `test:playwright` to
  `./run_playwright_tests.sh` and documented it in the front-door tables.

- `templates/typescript/noexist/package.json`: dependency-floor refresh; bumped 7 stale
  pins: `eslint` >=10.5.0 -> >=10.6.0, `typescript-eslint` >=8.61.0 -> >=8.62.1,
  `prettier` >=3.8.4 -> >=3.9.4, `playwright` >=1.60.0 -> >=1.61.1,
  `@playwright/test` >=1.60.0 -> >=1.61.1, `@types/node` >=25.9.3 -> >=26.0.1,
  `globals` >=17.6.0 -> >=17.7.0. Remaining 4 pins unchanged (already latest).

- `templates/typescript/noexist/package.json`: added top-level `allowScripts` block
  (`esbuild@0.28.1`, `fsevents@2.3.2`, `fsevents@2.3.3`) so esbuild's postinstall binary
  installs on a fresh `npm install`. Keys are version-pinned and maintained manually:
  after a sync that bumps esbuild or fsevents, re-apply the matching key by hand.

### Fixes and Maintenance

- `templates/typescript/docs/TYPESCRIPT_STYLE.md`: renamed `### Deployment shape` to
  `### Pages deployment shape` (3-6 word sentence-case heading rule; no in-doc anchor
  references to update).

### Decisions and Failures

- Doc-follows-experience stance: TYPESCRIPT_STYLE.md reconciliation was driven by evidence
  from real repos, not theory. Rules are updated to match observed working patterns rather
  than aspirational prescriptions. This stance is the standing policy for future doc updates.

- `deploy-pages.yml` ships at repo root (not under `.github/`): agents edit only repo-root
  files; a human completes the move into the workflows directory. Root placement is the
  convention so the seed ships cleanly from the template.

- `run_playwright_tests.sh` is untracked; the human stages it before committing.

- Validation: `pytest tests/` 1332 passed; `pytest tests/test_markdown_links.py` 32 passed.
