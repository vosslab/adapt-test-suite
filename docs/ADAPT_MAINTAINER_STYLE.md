# Observed ADAPT maintainer style

This guide summarizes conventions observed in nearby ADAPT source and recent upstream history.
Eric Kean is the project's primary maintainer and, by a wide margin, its most prolific contributor.
This is a contributor aid based on the style of that codebase, not an official guide authored or
approved by Eric Kean. When it conflicts with adjacent code or maintainer feedback, follow the
maintainer's direction and the local pattern.

## Scope discipline

- Keep a change focused on one user-visible behavior or one necessary correctness fix.
- Preserve legacy paths behind explicit guards when adding an opt-in assignment behavior.
- Prefer extending existing submission, score, seed, and assignment-property flows over replacing
  them.
- Avoid unrelated cleanup, renaming, formatting, or framework modernization in a feature patch.
- Keep local Podman, fixture, Playwright, and screenshot tooling outside the upstream source patch.

Representative paths: `app/Submission.php`, `app/Score.php`,
`app/Traits/AssignmentProperties.php`, and `resources/js/pages/questions.view.vue`.

## PHP and Laravel

Laravel is the PHP web application framework used by ADAPT. It provides the project's conventions
for models, database migrations, request validation, controllers, routing, and other server-side
application structure.

- Follow Laravel's existing model, request, controller, service, and facade patterns.
- Use constructor injection for a service dependency and route-model binding for controller models.
- Use snake_case for database-backed variables and request fields; use StudlyCase for classes.
- Put authorization and validation near the existing boundary that owns the operation.
- Use database transactions and row locks when one user action updates related lifecycle state.
- Return the existing response shapes and HTTP conventions instead of introducing a parallel API
  style.
- Add PHPDoc where it explains a public method's purpose or a non-obvious lifecycle boundary. Do
  not narrate straightforward statements line by line.

Representative paths: `app/Http/Controllers/AssignmentController.php`,
`app/Http/Requests/StoreAssignmentProperties.php`, `app/Services/WebworkMacroService.php`, and
`app/Services/MasteryAssignmentAttemptService.php`.

## Migrations and models

- Make schema changes additive and safe for existing rows.
- Supply explicit defaults for new assignment properties when legacy assignments need unchanged
  behavior.
- Add indexes and uniqueness constraints that enforce the lifecycle contract.
- Define a reversible `down()` method and document the table or column purpose briefly.
- Keep model casts, fillable fields, relationships, and status constants close to the model that
  owns them.

Representative paths: `database/migrations/2026_04_20_000004_create_webwork_macro_revisions_table.php`,
`database/migrations/2026_06_10_155408_create_webwork_macro_co_editors_table.php`, and
`app/MasteryAssignmentAttempt.php`.

## Vue and JavaScript

- Extend the existing BootstrapVue controls, alerts, badges, modals, and tooltips used by the page.
- Keep labels student- or instructor-facing and explain the consequence of a choice in its tooltip.
- Derive visibility and disabled state from the existing form or response object rather than
  introducing duplicate state.
- Keep API calls and error handling consistent with neighboring component methods.
- Use comments only for state transitions or compatibility constraints that are not evident from
  the template or method name.

Representative paths: `resources/js/components/AssignmentProperties.vue`,
`resources/js/helpers/AssignmentProperties.js`, and `resources/js/pages/questions.view.vue`.

## Tests and verification

- Add a focused Feature test beside the existing Laravel Feature suite for a new backend lifecycle.
- Prefer behavior assertions over assertions tied only to storage shape.
- Exercise the default-disabled legacy path as well as the opt-in path.
- Use repository-compatible factories, traits, and database helpers already present in
  `tests/Feature/`.
- At minimum, check PHP syntax, the production frontend build, focused tests, and `git diff --check`.
  Report unavailable or unrun checks explicitly.

Representative paths: `tests/Feature/AssignmentsSummaryTest.php`,
`tests/Feature/PassbackByAssignmentTest.php`, and `tests/Feature/MasteryAssignmentAttemptTest.php`.
