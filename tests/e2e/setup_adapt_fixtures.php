<?php

use App\Assignment;
use App\Course;
use App\MasteryAssignmentAttempt;
use App\Question;
use App\Section;
use App\User;
use Illuminate\Contracts\Console\Kernel;
use Illuminate\Support\Facades\DB;

require '/var/www/html/vendor/autoload.php';

$app = require '/var/www/html/bootstrap/app.php';
$app->make(Kernel::class)->bootstrap();

if ($argc !== 4) {
    throw new RuntimeException(
        'Usage: php setup_adapt_fixtures.php <instructor-email> <student-email> <base-url>'
    );
}

$instructor = User::where('email', $argv[1])->firstOrFail();
$student = User::where('email', $argv[2])->firstOrFail();
$base_url = rtrim($argv[3], '/');

if ((int)$instructor->role !== 2 || (int)$student->role !== 3) {
    throw new RuntimeException('Fixture accounts must be an instructor (role 2) and student (role 3).');
}

$result = DB::transaction(function () use ($instructor, $student, $base_url) {
    $now = now();
    if (!$student->central_identity_id) {
        $student->central_identity_id = sprintf('00000000-0000-4000-8000-%012d', $student->id);
        $student->save();
    }
    DB::table('key_secrets')->updateOrInsert(
        ['key' => 'forge'],
        ['secret' => 'local-test-only-forge-secret', 'created_at' => $now, 'updated_at' => $now]
    );
    $course = Course::updateOrCreate(
        ['name' => 'ADAPT Mastery Browser Tests', 'user_id' => $instructor->id],
        [
            'public_description' => 'Deterministic local data owned by adapt-test-suite.',
            'term' => 'Local Testing',
            'start_date' => $now->copy()->subYear(),
            'end_date' => $now->copy()->addYear(),
            'order' => 900,
            'public' => 0,
            'alpha' => 0,
            'anonymous_users' => 0,
            'school_id' => DB::table('schools')->min('id'),
            'shown' => 1
        ]
    );
    DB::table('final_grades')->updateOrInsert(
        ['course_id' => $course->id],
        [
            'letter_grades' => '90,A,80,B,70,C,60,D,0,F',
            'round_scores' => 0,
            'letter_grades_released' => 0,
            'created_at' => $now,
            'updated_at' => $now
        ]
    );

    $section = Section::updateOrCreate(
        ['course_id' => $course->id, 'name' => 'Browser Test Section'],
        ['crn' => 'ADAPT-E2E']
    );
    DB::table('enrollments')->updateOrInsert(
        ['user_id' => $student->id, 'course_id' => $course->id],
        [
            'section_id' => $section->id,
            'created_at' => $now,
            'updated_at' => $now
        ]
    );

    $native_questions = [
        upsertNativeQuestion(
            $instructor,
            $base_url,
            910000001,
            'Native Baseline: Primary Color',
            'Which color is a primary color?',
            'Blue',
            'Brown'
        ),
        upsertNativeQuestion(
            $instructor,
            $base_url,
            910000002,
            'Native Baseline: Even Number',
            'Which number is even?',
            '4',
            '5'
        )
    ];

    $webwork_questions = [
        upsertWebworkQuestion(
            $instructor,
            $base_url,
            910000101,
            'Mastery Variant: Limits',
            'Library/Rochester/setLimitsRates2Limits/ur_lr_2_9.pg'
        ),
        upsertWebworkQuestion(
            $instructor,
            $base_url,
            910000102,
            'Mastery Variant: Derivatives',
            'Library/Rochester/setDerivatives2Antiderivatives/ur_ad_1_3.pg'
        )
    ];

    $native_assignment = upsertAssignment(
        $course,
        'Native Question Baseline',
        901,
        false,
        false
    );
    attachQuestions($native_assignment, $native_questions);
    assignToCourse($native_assignment, $course, $now);

    $mastery_assignment = upsertAssignment(
        $course,
        'Whole-Assignment Mastery Retake',
        902,
        true,
        true
    );
    attachQuestions($mastery_assignment, $webwork_questions);
    assignToCourse($mastery_assignment, $course, $now);
    resetCompletedMasteryAttempt($mastery_assignment, $student, $webwork_questions, $now);

    return [
        'course_id' => $course->id,
        'section_id' => $section->id,
        'student_id' => $student->id,
        'native_assignment_id' => $native_assignment->id,
        'mastery_assignment_id' => $mastery_assignment->id
    ];
});

echo json_encode($result, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES) . PHP_EOL;

function upsertNativeQuestion(
    User $instructor,
    string $base_url,
    int $page_id,
    string $title,
    string $prompt,
    string $correct,
    string $incorrect
): Question {
    $qti_json = [
        'questionType' => 'multiple_choice',
        'prompt' => '<p>' . $prompt . '</p>',
        'simpleChoice' => [
            ['identifier' => 'correct', 'value' => '<p>' . $correct . '</p>', 'correctResponse' => true],
            ['identifier' => 'incorrect', 'value' => '<p>' . $incorrect . '</p>', 'correctResponse' => false]
        ],
        'feedback' => [],
        'randomizeOrder' => 'no'
    ];

    return Question::updateOrCreate(
        ['library' => 'adapt-test-suite', 'page_id' => $page_id],
        [
            'question_type' => 'assessment',
            'title' => $title,
            'technology_iframe' => '',
            'attachments' => json_encode([]),
            'technology' => 'qti',
            'open_ended_submission_type' => '0',
            'qti_json' => json_encode($qti_json),
            'qti_json_type' => 'multiple_choice',
            'non_technology' => 0,
            'non_technology_html' => '',
            'author' => $instructor->first_name . ' ' . $instructor->last_name,
            'question_editor_user_id' => $instructor->id,
            'license' => 'ccby',
            'license_version' => '4.0',
            'source_url' => $base_url,
            'public' => 0,
            'cached' => 0,
            'version' => 1
        ]
    );
}

function upsertWebworkQuestion(
    User $instructor,
    string $base_url,
    int $page_id,
    string $title,
    string $source_file_path
): Question {
    return Question::updateOrCreate(
        ['library' => 'adapt-test-suite', 'page_id' => $page_id],
        [
            'question_type' => 'assessment',
            'title' => $title,
            'technology_iframe' => '',
            'attachments' => json_encode([]),
            'technology' => 'webwork',
            'technology_id' => $source_file_path,
            'open_ended_submission_type' => '0',
            'non_technology' => 0,
            'non_technology_html' => '',
            'author' => $instructor->first_name . ' ' . $instructor->last_name,
            'question_editor_user_id' => $instructor->id,
            'license' => 'ccby',
            'license_version' => '4.0',
            'source_url' => $base_url,
            'public' => 0,
            'cached' => 0,
            'version' => 1
        ]
    );
}

function upsertAssignment(
    Course $course,
    string $name,
    int $order,
    bool $algorithmic,
    bool $mastery_retake_enabled
): Assignment {
    return Assignment::updateOrCreate(
        ['course_id' => $course->id, 'name' => $name],
        [
            'formative' => 0,
            'assessment_type' => 'real time',
            'can_submit_work' => 0,
            'number_of_allowed_attempts' => $mastery_retake_enabled ? '1' : '2',
            'number_of_allowed_attempts_penalty' => 0,
            'can_view_hint' => 0,
            'hint_penalty' => 0,
            'algorithmic' => $algorithmic ? 1 : 0,
            'mastery_retake_enabled' => $mastery_retake_enabled ? 1 : 0,
            'assignment_group_id' => DB::table('assignment_groups')->where('assignment_group', 'Homework')->value('id'),
            'source' => 'a',
            'number_of_randomized_assessments' => null,
            'scoring_type' => 'p',
            'points_per_question' => 'number of points',
            'default_points_per_question' => 5,
            'total_points' => 10,
            'show_points_per_question' => 1,
            'default_open_ended_submission_type' => '0',
            'late_policy' => 'not accepted',
            'shown' => 1,
            'show_scores' => 1,
            'solutions_released' => 0,
            'solutions_availability' => 'automatic',
            'include_in_weighted_average' => 1,
            'notifications' => 0,
            'order' => $order
        ]
    );
}

function attachQuestions(Assignment $assignment, array $questions): void
{
    foreach ($questions as $index => $question) {
        DB::table('assignment_question')->updateOrInsert(
            ['assignment_id' => $assignment->id, 'question_id' => $question->id],
            [
                'open_ended_submission_type' => '0',
                'points' => 5,
                'order' => $index + 1,
                'updated_at' => now()
            ]
        );
    }
}

function assignToCourse(Assignment $assignment, Course $course, $now): void
{
    $timing_ids = DB::table('assign_to_timings')
        ->where('assignment_id', $assignment->id)
        ->pluck('id');
    DB::table('assign_to_groups')->whereIn('assign_to_timing_id', $timing_ids)->delete();
    DB::table('assign_to_users')->whereIn('assign_to_timing_id', $timing_ids)->delete();
    DB::table('assign_to_timings')->where('assignment_id', $assignment->id)->delete();

    $timing_id = DB::table('assign_to_timings')->insertGetId([
        'assignment_id' => $assignment->id,
        'available_from' => $now->copy()->subDay(),
        'due' => $now->copy()->addMonth(),
        'final_submission_deadline' => $now->copy()->addMonth(),
        'created_at' => $now,
        'updated_at' => $now
    ]);
    DB::table('assign_to_groups')->insert([
        'assign_to_timing_id' => $timing_id,
        'group' => 'course',
        'group_id' => $course->id,
        'created_at' => $now,
        'updated_at' => $now
    ]);
    $enrolled_user_ids = DB::table('enrollments')
        ->where('course_id', $course->id)
        ->pluck('user_id');
    foreach ($enrolled_user_ids as $user_id) {
        DB::table('assign_to_users')->insert([
            'assign_to_timing_id' => $timing_id,
            'user_id' => $user_id,
            'created_at' => $now,
            'updated_at' => $now
        ]);
    }
}

function resetCompletedMasteryAttempt(
    Assignment $assignment,
    User $student,
    array $questions,
    $now
): void {
    $state_tables = [
        'submission_confirmations',
        'unconfirmed_submissions',
        'submission_histories',
        'shown_hints',
        'can_give_ups',
        'submissions',
        'seeds',
        'scores',
        'mastery_assignment_attempts'
    ];
    foreach ($state_tables as $table) {
        DB::table($table)
            ->where('assignment_id', $assignment->id)
            ->where('user_id', $student->id)
            ->delete();
    }

    $question_ids = array_map(function (Question $question) {
        return $question->id;
    }, $questions);
    $variants = [];
    foreach ($questions as $index => $question) {
        $seed = 41001 + $index;
        $variants[$question->id] = $seed;
    }

    MasteryAssignmentAttempt::create([
        'assignment_id' => $assignment->id,
        'user_id' => $student->id,
        'attempt_number' => 1,
        'status' => MasteryAssignmentAttempt::STATUS_COMPLETED,
        'question_ids' => $question_ids,
        'variant_identifiers' => $variants,
        'question_results' => [],
        'score' => 5,
        'possible_score' => 10,
        'completed_at' => $now
    ]);
    DB::table('scores')->insert([
        'user_id' => $student->id,
        'assignment_id' => $assignment->id,
        'score' => 5,
        'created_at' => $now,
        'updated_at' => $now
    ]);
}
