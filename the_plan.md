# Whole-assignment attempts: implementation outcome

## Authoritative status

This section records the implementation contract as of 2026-07-18. It supersedes conflicting
requirements in the historical proposal below. The proposal remains intact as a record of the
design process.

### Pull request boundary

The work is split into two sequential pull requests:

1. Clarify the existing random-question-subset controls and question-count display.
2. Add the opt-in whole-assignment attempt policy and its complete guarded lifecycle.

The second pull request keeps its migration, backend coordinator, instructor controls, student
flow, and focused feature coverage together. Splitting those parts further would leave incomplete
states on the upstream branch.

### Final instructor contract

The instructor selects an `Assignment Attempt Policy`:

- `Per-question attempts` preserves ADAPT's existing response limits and immediate feedback.
- `Whole-assignment attempts` gives each question one response in an assignment attempt, then
  allows another complete attempt when the configured limit permits it.

Whole-assignment attempts support finite limits or unlimited attempts. Earning 100% records a
mastered attempt but does not prevent continued practice while another attempt is available.
Assignment grading retains the student's highest completed score, so additional practice cannot
lower the assignment score.

Eligible assignments are real-time, point-scored assignments with positive points and supported
automatically graded questions. Supported question technologies are Native, WeBWorK, and IMathAS.
H5P remains unsupported.

### Final student contract

- Feedback remains immediate after each question response.
- Completing an attempt requires one response to every included question.
- Until a new attempt starts, the current responses and feedback remain available after leaving
  and returning to the assignment.
- Starting a new attempt replaces the current response state and includes every question again.
- Native questions reuse their fixed problem versions.
- Algorithmic WeBWorK and IMathAS questions receive fresh variants only when algorithmic question
  variation is enabled.
- A persistent inline completion panel replaces an additional completion popup. It reports the
  completed attempt, explains that the highest score stays the same, and presents a numbered
  `Start Attempt N` action when another attempt is available.

### Persistence and API boundary

`mastery_assignment_attempts` is the authoritative assignment-attempt snapshot. Each row records
the student and assignment, attempt number and status, included question IDs, variant identifiers,
question results, completed score, possible score, and completion time. Current submission tables
remain the source used by ADAPT's existing renderers and graders; starting a new attempt replaces
that current response state rather than adding a historical response viewer.

Mastery-enabled assignment responses include the current attempt summary. The guarded retake
endpoint starts the next attempt from a completed attempt. Submission requests carry the attempt
identifier so missing, stale, or closed-attempt requests can return a conflict without mutating the
new attempt. Assignments without the option enabled continue through the legacy paths.

### Verification status

Verified locally:

- The additive migrations apply to a fresh MySQL database in the Podman worktree environment.
- The production frontend image builds successfully.
- Four Playwright tests pass against the local Podman environment.
- Browser coverage exercises the legacy per-question Native flow and the Native
  whole-assignment completion, review, and restart flow.
- The source and external test repositories pass `git diff --check` for the reviewed changes.

Not yet verified:

- The focused PHPUnit suite has not been rerun in a compatible development container because the
  production image omits development dependencies.
- A live WeBWorK workflow has not been run because the local environment has no WeBWorK backend.
- IMathAS has not been exercised end to end.
- LMS score passback and passback failure recovery have not been exercised end to end.
- The complete upstream Feature suite has not been run.

### Deviations from the proposal

The implementation differs from the original proposal in several deliberate ways:

- The instructor control is an assignment-attempt policy rather than a mastery-retake checkbox.
- Assignment-attempt limits can be finite or unlimited.
- Practice may continue after a 100% attempt; mastery does not force an early stop.
- Native questions are supported with fixed versions rather than being rejected for lacking fresh
  variants.
- Fresh variants apply only to algorithmic WeBWorK and IMathAS questions when variation is enabled.
- The student completion experience uses a persistent inline panel instead of a second modal.
- The user-facing language distinguishes a question response from a complete assignment attempt.
- Random-question-subset wording is isolated in the first pull request.

# Historical proposal

The following 559-line proposal is preserved for context. Its future-tense requirements are not the
authoritative description of the implemented pull requests.

  # Plan: Mastery-based whole-assignment retakes

  ## Context

  The pedagogical goal is to let students practice an entire algorithmic assignment repeatedly, receiving a genuinely different
  problem instance on each retake, until every question is correct in one assignment attempt. This captures the mastery loop from the
  BBQ/Blackboard workflow (https://biologyproblems.org/tutorials/bbq_tutorial/) without reproducing Blackboard's explicit
  question-pool model.

  ADAPT currently stores one active submission and one active variant identifier per student, assignment, and question. Attempts are
  question-level rather than assignment-level. The implementation must add an opt-in assignment-attempt lifecycle without rewriting
  ADAPT's large shared submission system.

  Implementation must begin from the current origin/master, not the older local main branch.

  ## Objectives

  - Add one limited, instructor-enabled mastery-retake workflow.
  - Require one graded response per question in each assignment attempt.
  - Generate a genuinely different variant of every question when a failed attempt is restarted.
  - Preserve the highest completed attempt score and stop retakes after 100% mastery.
  - Leave every assignment without the new option behaviorally unchanged.
  - Deliver one focused upstream PR suitable for a first-time contributor.

  ## Design philosophy

  Preserve ADAPT's existing renderers, graders, per-question feedback, submission rows, and score records. Add a small assignment-
  attempt coordinator around those systems rather than introducing a new assessment engine or changing existing unique keys.

  "Supports fresh variants" is a pedagogical capability, not a public synonym for "has a seed." WeBWorK and IMathAS currently
  implement that capability with seeds, but the mastery component will use capability-oriented names. A generalized policy framework
  and normalized replacement for ADAPT's submission model are rejected for this first PR.

  ## Scope

  - Add an instructor checkbox named Enable whole-assignment mastery retakes.
  - Support algorithmic, point-scored, real-time assignments whose questions all produce fresh variants.
  - Initially recognize WeBWorK and IMathAS as fresh-variant providers.
  - Give each question exactly one graded response per assignment attempt by reusing ADAPT's existing number_of_allowed_attempts = 1
    behavior.

  - Complete an attempt automatically after every assigned question has one submission.
  - Preserve current immediate per-question feedback.
  - Allow unlimited failed retakes.
  - Retain the highest completed attempt score.
  - Lock the assignment after an attempt in which every question is correct.
  - Preserve the attached question set and order while replacing every question's generated variant.
  - Reject stale submissions originating from an earlier attempt.
  - Add migrations, server-side validation, feature tests, build verification, and a concise user-facing explanation.

  ## Non-goals

  - Do not introduce an explicit question-pool entity.
  - Do not support QTI/native questions, because their content is flat even when presentation order is shuffled.
  - Do not support H5P, Forge, open-ended work, learning trees, clickers, flashcards, or mixed-technology assignments.
  - Do not support ADAPT's random sampling of attached question records in this PR.
  - Do not add draft responses or an explicit Submit Assignment finalization step.
  - Do not add instructor-selectable attempt limits, scoring methods, feedback timing, or post-mastery practice.
  - Do not add timers or auto-submit; timing requires a separate plan and PR.
  - Do not add all-at-once question presentation or randomized question order.
  - Do not add a historical attempt-response viewer.
  - Do not refactor Submission::store(), replace existing submission tables, or relax their unique constraints.

  ## Current state summary

  - submissions, seeds, and scores represent only the student's current assignment state.
  - number_of_allowed_attempts limits submissions per question.
  - completedAllAssignmentQuestions() detects whether every required question has a submission, but it does not define a persistent
    assignment attempt.

  - Submission::store() handles multiple technologies, grading, penalties, score recomputation, and LMS passback; broad changes there
    carry high regression risk.

  - WeBWorK and IMathAS both generate new problem instances from replaceable numeric variant identifiers.
  - QTI's optional identifiers shuffle answer presentation rather than generating a new problem.
  - Existing reset behavior demonstrates which current-state records must be cleared, but it deletes history and is question-scoped.

  ## Architecture boundaries and ownership

  ### Data contract

  Add mastery_retake_enabled, defaulting to false, to assignments and assignment templates.

  Add mastery_assignment_attempts with:

  - id
  - assignment_id
  - user_id
  - attempt_number
  - status: in_progress, completed, or mastered
  - question_ids JSON
  - variant_identifiers JSON
  - score and possible_score
  - completed_at
  - timestamps
  - unique constraint on (assignment_id, user_id, attempt_number)

  An attempt row is created when an eligible student first launches the assignment. It provides stable attempt identity and a row
  that can be locked during concurrent submissions.

  ### Capability and lifecycle contract

  - Add a small capability check such as supportsFreshVariant(); initially it returns true only for WeBWorK and IMathAS.
  - Add one mastery-attempt service responsible for eligibility, active-attempt creation, locking, completion, highest-score
    selection, variant replacement, and retake authorization.

  - Keep technology-specific variant generation in ADAPT's existing variant-generation path.
  - Do not add adapter classes or a provider hierarchy for two technologies that already share the same mechanism.

  ### Public interfaces

   Interface                       Contract
  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   Assignment property             mastery_retake_enabled: boolean
  ------------------------------  ---------------------------------------------------------------------------------------------------
   Existing assignment response    Add mastery_attempt with id, number, status, score, possible_score, and can_retake; return null
                                   for legacy assignments
  ------------------------------  ---------------------------------------------------------------------------------------------------
   Retake endpoint                 POST /api/assignments/{assignment}/mastery-attempts; starts the next attempt only after a failed
                                   completed attempt
  ------------------------------  ---------------------------------------------------------------------------------------------------
   Problem JWT                     Add optional adapt.mastery_attempt_id; require and validate it only when mastery retakes are
                                   enabled
  ------------------------------  ---------------------------------------------------------------------------------------------------
   Conflict response               Return HTTP 409 without mutation for stale, duplicate, already-mastered, or otherwise invalid
                                   retake/submission requests

  ### Eligibility contract

  Strict student launch validation requires:

  - assessment_type = real time
  - point-based scoring
  - algorithmic = true
  - number_of_allowed_attempts = 1
  - at least one assigned question
  - every question supports fresh variants
  - no open-ended or submitted-work requirement
  - no hint, attempt, or late-deduction policy that can prevent an all-correct attempt from earning full credit
  - no ADAPT random-sampling setting

  A blank assignment or template may store the option during authoring, but student launch remains blocked until the final question
  set satisfies the contract. Once a real student attempt exists, the setting and assignment question membership become locked
  through ADAPT's existing student-work lock behavior.

  ### Mapping (milestones / workstreams -> components / patches)

   Milestone / Workstream    Component                                   Expected patches
  ━━━━━━━━━━━━━━━━━━━━━━━━  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   M0 / WS-A                 Upstream design contract                    Approval artifact, no source patch
  ------------------------  ------------------------------------------  ------------------------------------
   M1 / WS-B                 Mastery attempt data and eligibility        Patch 1
  ------------------------  ------------------------------------------  ------------------------------------
   M1 / WS-C                 Submission, score, and variant lifecycle    Patch 1
  ------------------------  ------------------------------------------  ------------------------------------
   M2 / WS-D                 Instructor assignment properties            Patch 1
  ------------------------  ------------------------------------------  ------------------------------------
   M2 / WS-E                 Student attempt and retake experience       Patch 1
  ------------------------  ------------------------------------------  ------------------------------------
   M3 / WS-F                 Feature and regression verification         Patch 1
  ------------------------  ------------------------------------------  ------------------------------------
   M3 / WS-G                 Review and documentation                    Patch 1

  Patch 1 is intentionally one atomic upstream PR. Splitting its schema from its guarded end-to-end behavior would leave unused
  infrastructure on master.

  ## Milestone plan

   M      Title                          Summary                                        Goal
  ━━━━━  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   M0     Upstream alignment             Present the limited behavior and data          Confirm that the maintainer welcomes the
                                         contract before coding                         bounded approach
  -----  -----------------------------  ---------------------------------------------  ----------------------------------------------
   M1     Attempt lifecycle              Add the opt-in data, validation, locking,      Establish a safe server-side mastery state
                                         scoring, and variant behavior                  machine
  -----  -----------------------------  ---------------------------------------------  ----------------------------------------------
   M2     Instructor and student flow    Expose the checkbox, status, completion        Make the workflow understandable without
                                         messaging, and retake action                   changing normal assignments
  -----  -----------------------------  ---------------------------------------------  ----------------------------------------------
   M3     Regression and submission      Exercise supported and unsupported paths       Demonstrate legacy compatibility and review
                                         and prepare the focused PR                     readiness

  ### Milestone M0: Upstream alignment

  - Depends on: none.
  - Workstreams: WS-A.
  - Entry criteria: this plan is accepted by the contributor.
  - Exit criteria:
      - Send the maintainer a one-page proposal containing the pedagogical loop, eligibility boundary, schema, API, legacy guarantee,
        and non-goals.

      - Confirm that one opinionated workflow is preferable to a generalized policy system.
      - Incorporate requested scope corrections into this plan before source work starts.

  - Parallel-plan ready: no - external design acceptance is inherently serial.

  ### Milestone M1: Attempt lifecycle

  - Depends on: DEC-1 - maintainer acceptance of the limited contract.
  - Workstreams: WS-B and WS-C.
  - Entry criteria: approved schema, API names, and eligibility boundary.
  - Exit criteria:
      - Default-disabled migrations apply on a fresh MySQL database.
      - Active attempts are created and locked transactionally.
      - Attempt completion is recorded exactly once.
      - Failed retakes produce a different variant for every question.
      - Highest completed scores survive active-state resets.
      - Stale callbacks cannot mutate the new attempt.
      - Targeted feature tests pass.

  - Parallel-plan ready: yes - maximum two doers after the schema contract is fixed.

  ### Milestone M2: Instructor and student flow

  - Depends on: CONTRACT-1 and CONTRACT-2 - eligibility and lifecycle APIs must be stable.
  - Workstreams: WS-D and WS-E.
  - Entry criteria: backend request and response contracts pass feature tests.
  - Exit criteria:
      - Instructors can enable the option only with an actionable explanation of its requirements.
      - Students see the attempt number and correct completion state.
      - Failed completion offers one idempotent retake action.
      - Mastery completion offers no further retake action.
      - The production frontend build passes.

  - Parallel-plan ready: yes - maximum two doers because the instructor and student views are separate.

  ### Milestone M3: Regression and submission

  - Depends on: PATCH-1-ASSEMBLED - backend and frontend behavior are integrated.
  - Workstreams: WS-F and WS-G.
  - Entry criteria: targeted tests and the production frontend build pass.
  - Exit criteria:
      - Full feature CI passes against MySQL.
      - Manual WeBWorK and IMathAS workflows pass.
      - Legacy assignments show no new behavior.
      - PR contains no timing, pool, QTI, H5P, general policy, or unrelated cleanup changes.
      - PR description documents migration, rollback, screenshots, tests, and explicit non-goals.

  - Parallel-plan ready: yes - maximum two read-only verification/review doers.

  ## Workstream breakdown

  ### Workstream WS-A: Maintainer contract

  - Owner: planner, with architect review.
  - Needs: this plan and current repository evidence.
  - Provides: DEC-1, the approved upstream boundary.
  - Expected patches: none.

  ### Workstream WS-B: Data and eligibility

  - Owner: expert_coder.
  - Needs: DEC-1.
  - Provides: schema, model, capability check, validation, and locking predicate.
  - Expected patches: contributes the data portion of Patch 1.

  ### Workstream WS-C: Lifecycle and scoring

  - Owner: expert_coder.
  - Needs: the WS-B schema contract.
  - Provides: active-attempt orchestration, completion, retake, score retention, and stale-request protection.
  - Expected patches: contributes the backend behavior portion of Patch 1.

  ### Workstream WS-D: Instructor experience

  - Owner: coder.
  - Needs: eligibility error and property contracts.
  - Provides: checkbox, help text, validation display, and locked-state behavior.
  - Expected patches: contributes the instructor UI portion of Patch 1.

  ### Workstream WS-E: Student experience

  - Owner: coder.
  - Needs: attempt response and retake endpoint contracts.
  - Provides: attempt status, completion messages, and retake action.
  - Expected patches: contributes the student UI portion of Patch 1.

  ### Workstream WS-F: Verification

  - Owner: tester.
  - Needs: assembled Patch 1.
  - Provides: focused feature tests, negative cases, score/passback tests, and regression results.
  - Expected patches: test portion of Patch 1.

  ### Workstream WS-G: Review and documentation

  - Owner: reviewer; planner owns PR prose.
  - Needs: completed implementation and verification results.
  - Provides: read-only defect review and final upstream PR description.
  - Expected patches: documentation corrections only if required in Patch 1.

  ## Work packages

  ### Work package WP-A1: Obtain upstream design acceptance

  - Owner: planner.
  - Touch points: maintainer proposal only.
  - Depends on: none.
  - Acceptance criteria: maintainer has reviewed the bounded workflow or supplied requested corrections.
  - Verification commands: none.
  - Obvious follow-ons: update the plan and repeat the design gate if the contract changes.

  ### Work package WP-B1: Add the assignment-attempt schema

  - Owner: expert_coder.
  - Touch points: migrations, assignment properties, attempt model.
  - Depends on: DEC-1.
  - Acceptance criteria: migrations are additive, default-disabled, indexed, and preserve existing rows.
  - Verification commands:
      - php artisan migrate
      - vendor/bin/phpunit --filter AssignmentPropertiesTest

  - Obvious follow-ons: update assignment-template copying and model casts.

  ### Work package WP-B2: Enforce fresh-variant eligibility

  - Owner: expert_coder.
  - Touch points: question capability and assignment validation.
  - Depends on: WP-B1.
  - Acceptance criteria: WeBWorK and IMathAS pass; QTI/native, H5P, mixed, sampled, penalized, and manual-response assignments fail
    with actionable validation.

  - Verification commands:
      - vendor/bin/phpunit --filter MasteryRetake

  - Obvious follow-ons: apply the same validator at property save and student launch.

  ### Work package WP-C1: Implement the attempt state machine

  - Owner: expert_coder.
  - Touch points: mastery-attempt service and narrow submission hook.
  - Depends on: WP-B1, WP-B2.
  - Acceptance criteria: attempts transition only from in_progress to completed or mastered, with transactional locking and unique
    completion.

  - Verification commands:
      - vendor/bin/phpunit --filter MasteryRetake

  - Obvious follow-ons: cover duplicate and concurrent completion paths.

  ### Work package WP-C2: Implement safe retakes and score retention

  - Owner: expert_coder.
  - Touch points: retake endpoint, active-state cleanup, variant generation, score update.
  - Depends on: WP-C1.
  - Acceptance criteria:
      - Retake clears only current attempt submissions, hints, give-up state, histories, confirmations, and variant records.
      - Attached questions and their order remain unchanged.
      - Every replacement variant differs from the immediately preceding attempt.
      - Assignment and LMS scores change only when an attempt completes and never fall below the highest completed score.

  - Verification commands:
      - vendor/bin/phpunit --filter MasteryRetake
      - vendor/bin/phpunit --filter PassbackByAssignmentTest

  - Obvious follow-ons: verify the reset list against both WeBWorK confirmation paths and IMathAS direct submission.

  ### Work package WP-C3: Reject stale submissions

  - Owner: expert_coder.
  - Touch points: problem JWT creation and callback validation.
  - Depends on: WP-C1.
  - Acceptance criteria: an earlier attempt's callback returns 409 and creates or updates no submission, score, confirmation, or
    history row.

  - Verification commands:
      - vendor/bin/phpunit --filter MasteryRetake
      - vendor/bin/phpunit --filter WebworkSubmissionErrorsTest

  - Obvious follow-ons: verify legacy JWTs remain accepted for assignments where mastery retakes are disabled.

  ### Work package WP-D1: Add the instructor control

  - Owner: coder.
  - Touch points: assignment-property request, helper, and Vue form.
  - Depends on: WP-B2.
  - Acceptance criteria: one checkbox and concise help text are exposed; incompatible settings produce specific errors; the property
    locks after real student work.

  - Verification commands:
      - vendor/bin/phpunit --filter AssignmentPropertiesTest
      - npm run production

  - Obvious follow-ons: include the property in assignment summaries and template serialization without adding new policy controls.

  ### Work package WP-E1: Add the student retake flow

  - Owner: coder.
  - Touch points: assignment question payload and student question view.
  - Depends on: WP-C2, WP-C3.
  - Acceptance criteria: attempt number, failed-completion action, mastered state, loading state, and 409 recovery are visible and
    accessible.

  - Verification commands:
      - vendor/bin/phpunit --filter QuestionsViewTest
      - npm run production

  - Obvious follow-ons: refresh the assignment payload after retake so no stale iframe remains mounted.

  ### Work package WP-F1: Complete feature and regression coverage

  - Owner: tester.
  - Touch points: feature tests only.
  - Depends on: WP-D1, WP-E1.
  - Acceptance criteria: all acceptance scenarios below have automated coverage where feasible.
  - Verification commands:
      - vendor/bin/phpunit --filter MasteryRetake
      - vendor/bin/phpunit --filter Feature --stop-on-failure

  - Obvious follow-ons: reproduce and fix every failing legacy test before submission.

  ### Work package WP-G1: Audit and prepare the upstream PR

  - Owner: reviewer.
  - Touch points: complete diff and PR description.
  - Depends on: WP-F1.
  - Acceptance criteria: no blocker/high-risk review finding remains and every changed line belongs to the stated scope.
  - Verification commands:
      - git diff --check
      - git diff --stat origin/master...HEAD

  - Obvious follow-ons: rerun targeted and full gates after every review correction.

  ## Acceptance criteria and gates

  - Per-patch gate:
      - Assignments with the option disabled follow the legacy code path.
      - Migration, targeted PHPUnit tests, production frontend build, and git diff --check pass.

  - Integration gate:
      - A failed WeBWorK attempt can be reviewed and restarted with every problem changed.
      - An IMathAS assignment follows the identical assignment-attempt lifecycle.
      - A second attempt cannot reduce the persisted or passed-back best score.
      - A 100% attempt becomes mastered and cannot be restarted.
      - Stale and duplicate requests are idempotently rejected.

  - Manual review gate:
      - Instructor enabling, validation, student completion, retake, reload, mastery, and LMS-score behavior are demonstrated.
      - An ordinary non-mastery assignment is manually compared before and after the patch.

  ## Test and verification strategy

  - Unit-test the fresh-variant capability and eligibility validator.
  - Feature-test assignment and template property persistence, validation, and locking.
  - Feature-test first launch, partial progress, failed completion, retake, fresh variants, second completion, and mastery.
  - Test one-response-per-question enforcement through the existing attempt limit.
  - Test active-attempt row locking, duplicate final submissions, duplicate retake clicks, and stale JWT callbacks.
  - Test that partial retakes do not change the recorded highest completed assignment score or trigger LMS passback.
  - Test unsupported QTI/native, H5P, mixed, sampled, manual, and penalized configurations.
  - Run the repository's CI-equivalent command: vendor/bin/phpunit --filter Feature --stop-on-failure.
  - Run npm run production.
  - Manually smoke-test one WeBWorK and one IMathAS assignment using the local Podman environment.

  Any failure in migrations, stale-request protection, score/passback behavior, the full Feature suite, or the legacy manual
  comparison blocks PR submission.

  ## Migration and compatibility policy

  - Additive rollout: add one default-false property and one new table; do not rewrite existing data.
  - Backward compatibility: assignments without the option never create attempt rows, require attempt JWT claims, or enter mastery-
    specific score logic.

  - Legacy deletion criteria: no legacy path or table is deleted by this plan.
  - Rollback strategy:
      - Before real mastery attempts exist, revert the code and migrations normally.
      - After real attempts exist, disable new activation and roll forward with a corrective patch; do not drop attempt history as
        part of an emergency rollback.

      - Keep the setting immutable once real attempt rows exist so disabling it cannot strand or reinterpret student work.

  ## Risk register

   Risk                               Impact    Trigger                             Owner           Mitigation
  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  ━━━━━━━━  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  ━━━━━━━━━━━━━━  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   Regression in shared submission    High      Legacy submission tests or          expert_coder    Default-false guard and minimal
   handling                                     manual comparison changes                           hook in the existing transaction
  ---------------------------------  --------  ----------------------------------  --------------  ----------------------------------
   Score or LMS passback falls        High      Stored/passback score becomes       expert_coder    Update assignment grade only on
   during a retake                              lower than a completed attempt                      attempt completion and take the
                                                                                                    maximum completed score
  ---------------------------------  --------  ----------------------------------  --------------  ----------------------------------
   Old browser tab submits into a     High      JWT attempt ID differs from         expert_coder    Validate mastery_attempt_id
   new attempt                                  active row                                          before any mutation and return
                                                                                                    409
  ---------------------------------  --------  ----------------------------------  --------------  ----------------------------------
   Two final responses race           High      Duplicate/missing completion        expert_coder    Lock the active attempt row and
                                                record                                              enforce the unique attempt
                                                                                                    number
  ---------------------------------  --------  ----------------------------------  --------------  ----------------------------------
   A "new" attempt repeats a          Medium    New variant identifier equals       expert_coder    Generate and compare all
   problem                                      the preceding one                                   replacements transactionally
                                                                                                    before returning success
  ---------------------------------  --------  ----------------------------------  --------------  ----------------------------------
   Unsupported content is enabled     Medium    Eligibility fails during launch     coder           Central validator at save and
                                                                                                    launch with specific instructor
                                                                                                    errors
  ---------------------------------  --------  ----------------------------------  --------------  ----------------------------------
   Assignment changes after           High      Question set or setting changes     expert_coder    Treat real attempt rows as
   student work                                 after attempt creation                              student work in existing lock
                                                                                                    checks
  ---------------------------------  --------  ----------------------------------  --------------  ----------------------------------
   Scope expands into assessment      High      PR adds pools, timing, drafts,      reviewer        Reject unrelated changes and
   redesign                                     or generalized policies                             keep them in separate plans/PRs

  ## Rollout and release checklist

  - [ ] Obtain maintainer design acceptance before source work.
  - [ ] Branch from an updated origin/master.
  - [ ] Preserve the user's existing local Podman files and unrelated worktree changes.
  - [ ] Apply migrations against a fresh MySQL test database.
  - [ ] Pass targeted mastery, assignment-property, score, passback, and callback tests.
  - [ ] Pass the full Feature suite.
  - [ ] Pass the production frontend build.
  - [ ] Complete WeBWorK, IMathAS, and legacy manual smoke tests.
  - [ ] Complete read-only defect and scope review.
  - [ ] Submit one focused upstream PR with screenshots, test evidence, migration notes, and explicit non-goals.

  ## Documentation close-out requirements

  - Active plan / progress tracker: the repository has no established active-plan location; keep execution status in the PR checklist
    rather than adding a new planning subsystem.

  - docs/CHANGELOG.md entry: do not create a new changelog solely for this PR; update an existing canonical release note only if the
    maintainer identifies one during DEC-1.

  - Archive / closure notes: preserve the final behavior contract, validation rules, test evidence, and known exclusions in the PR
    description.

  - Instructor help text must explain that the mode gives one response per question, unlimited full-assignment retakes, fresh
    algorithmic variants, highest-score retention, and completion at 100%.

  ## Patch plan and reporting format

  - Patch 1: add the complete, default-disabled mastery-retake workflow for fresh-variant WeBWorK and IMathAS assignments.
      - Data: assignment property and attempt table.
      - Backend: capability validation, attempt lifecycle, stale-request protection, score retention, and retake endpoint.
      - Frontend: instructor checkbox, attempt status, completion messaging, and retake action.
      - Verification: migrations, feature tests, frontend build, manual smoke evidence, and PR documentation.

  Timing, explicit finalization, configurable policies, native/QTI support, H5P support, ADAPT question sampling, and post-mastery
  practice each require a separate maintainer-approved plan and PR.

  ## Resolved decisions

  - "Fresh variant" describes capacity to vary, not the presence of a field named seed.
  - Initial providers are WeBWorK and IMathAS.
  - QTI/native and H5P are outside the first PR.
  - The first PR supplies one opinionated mastery workflow rather than configurable policies.
  - Attempts complete automatically after the final question response.
  - Students receive existing immediate per-question feedback.
  - Retakes are unlimited, highest completed score wins, and 100% mastery locks further attempts.
  - Attached question records and order remain fixed; only generated problem variants change.
  - Timing belongs in its own PR.
  - The upstream deliverable is one focused PR.

  ## Open questions and decisions needed

  None for the implementer. If the maintainer rejects or changes any contract during M0, revise this plan and repeat the design gate
  before implementation.
