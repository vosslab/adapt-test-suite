#!/usr/bin/env bash

set -Eeuo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
readonly REPO_ROOT

# Use the repository's documented Python environment before invoking PyYAML.
source "$REPO_ROOT/source_me.sh"

ADAPT_SOURCE_DIR="${ADAPT_SOURCE_DIR:-$REPO_ROOT/../libretexts-adapt}"
ADAPT_REF="${ADAPT_REF:-origin/master}"
ADAPT_IMAGE="${ADAPT_IMAGE:-localhost/libretexts-adapt:local}"
ADAPT_PORT="${ADAPT_PORT:-8080}"
ADAPT_NETWORK="${ADAPT_NETWORK:-adapt-local}"
ADAPT_APP_CONTAINER="${ADAPT_APP_CONTAINER:-adapt-app}"
ADAPT_DB_CONTAINER="${ADAPT_DB_CONTAINER:-adapt-mysql}"
ADAPT_REDIS_CONTAINER="${ADAPT_REDIS_CONTAINER:-adapt-redis}"
ADAPT_DB_VOLUME="${ADAPT_DB_VOLUME:-adapt-mysql-data}"
ADAPT_DB_DATABASE="${ADAPT_DB_DATABASE:-adapt}"
ADAPT_DB_USERNAME="${ADAPT_DB_USERNAME:-adapt}"
ADAPT_DB_PASSWORD="${ADAPT_DB_PASSWORD:-adapt_local_password}"
ADAPT_DB_ROOT_PASSWORD="${ADAPT_DB_ROOT_PASSWORD:-adapt_local_root_password}"
ADAPT_LOCAL_CONFIG="${ADAPT_LOCAL_CONFIG:-$REPO_ROOT/podman-local.yml}"
ADAPT_COMMAND_NAME="${ADAPT_COMMAND_NAME:-$0}"
BUILD_TEMPORARY_DIRECTORY=""

cleanup_build_temporary_directory() {
    if [[ -n "$BUILD_TEMPORARY_DIRECTORY" && -d "$BUILD_TEMPORARY_DIRECTORY" ]]; then
        rm -rf "$BUILD_TEMPORARY_DIRECTORY"
    fi
    BUILD_TEMPORARY_DIRECTORY=""
}

trap cleanup_build_temporary_directory EXIT

usage() {
    local command_name
    command_name="$(basename "$ADAPT_COMMAND_NAME")"
    cat <<EOF
Usage: ./$command_name COMMAND

Commands:

  up       Start ADAPT with the preserved database; build the image if missing.
           Apply migrations and ensure accounts and fixtures exist.
  rebuild  Rebuild the image from the current source, preserve the database,
           and start ADAPT.
  reset    Replace the database, start ADAPT, and recreate accounts and fixtures.
  build    Build only the application image.
  setup-account
           Start ADAPT if needed and update accounts from podman-local.yml.
  setup-fixtures
           Start ADAPT if needed and reset the deterministic test course.
  down     Remove containers; preserve the image and database.
  clean    Remove containers, image, database volume, and network.
  logs     Follow the application logs.
  status   Show container status and the application URL.
  help     Show this command reference.
EOF
}

die() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

require_local_config() {
    [[ -r "$ADAPT_LOCAL_CONFIG" ]] || die \
        "local account file not found or unreadable: $ADAPT_LOCAL_CONFIG (copy podman-local.example.yml first)"
}

yaml_value() {
    local key="$1"
    python3 -c '
import sys
import yaml

with open(sys.argv[1], encoding="utf-8") as config_file:
    value = yaml.safe_load(config_file) or {}
for part in sys.argv[2].split("."):
    if not isinstance(value, dict) or part not in value:
        raise SystemExit(f"missing YAML value: {sys.argv[2]}")
    value = value[part]
print(value, end="")
' "$ADAPT_LOCAL_CONFIG" "$key"
}

ensure_podman() {
    require_command podman
    if podman info >/dev/null 2>&1; then
        return
    fi

    if [[ "$(uname -s)" != "Darwin" ]]; then
        die "Podman is installed, but its service is unavailable"
    fi

    printf 'Podman machine is not running; starting it...\n'
    if ! podman machine inspect >/dev/null 2>&1; then
        printf 'No Podman machine exists; creating one...\n'
        podman machine init --cpus 4 --memory 6144 --disk-size 40
    fi
    podman machine start
    podman info >/dev/null 2>&1 || die "Podman machine started but Podman is still unavailable"
}

container_exists() {
    podman container exists "$1"
}

container_running() {
    [[ "$(podman inspect --format '{{.State.Running}}' "$1" 2>/dev/null || true)" == "true" ]]
}

remove_container() {
    if container_exists "$1"; then
        podman rm --force "$1" >/dev/null
    fi
}

composer_auth_file() {
    local destination="$1"

    if [[ -n "${COMPOSER_AUTH_FILE:-}" ]]; then
        [[ -r "$COMPOSER_AUTH_FILE" ]] || die "COMPOSER_AUTH_FILE is not readable: $COMPOSER_AUTH_FILE"
        cp "$COMPOSER_AUTH_FILE" "$destination"
    elif [[ -n "${COMPOSER_AUTH:-}" ]]; then
        printf '%s' "$COMPOSER_AUTH" >"$destination"
    elif [[ -r "$REPO_ROOT/auth.json" ]]; then
        cp "$REPO_ROOT/auth.json" "$destination"
    else
        printf '{}\n' >"$destination"
        SKIP_LICENSED_PDF_PARSER=1
    fi

    chmod 600 "$destination"
}

omit_licensed_pdf_parser() {
    local context="$1" temporary_file
    require_command jq

    printf 'No Composer credentials found; omitting the licensed Setasign PDF parser from this local image.\n'
    temporary_file="$context/composer.json.tmp"
    jq 'del(.require["setasign/fpdi_pdf-parser"])' "$context/composer.json" >"$temporary_file"
    mv "$temporary_file" "$context/composer.json"

    temporary_file="$context/composer.lock.tmp"
    jq '.packages |= map(select(.name != "setasign/fpdi_pdf-parser"))' \
        "$context/composer.lock" >"$temporary_file"
    mv "$temporary_file" "$context/composer.lock"
}

stage_source() {
    local destination="$1"

    mkdir -p "$destination"
    if [[ "$ADAPT_REF" == "WORKTREE" ]]; then
        tar \
            --exclude='.git' \
            --exclude='.env' \
            --exclude='auth.json' \
            --exclude='podman-local.yml' \
            --exclude='node_modules' \
            --exclude='vendor' \
            -C "$ADAPT_SOURCE_DIR" -cf - . | tar -C "$destination" -xf -
    else
        git -C "$ADAPT_SOURCE_DIR" rev-parse --verify "${ADAPT_REF}^{commit}" >/dev/null 2>&1 \
            || die "Git ref does not exist locally: $ADAPT_REF"
        git -C "$ADAPT_SOURCE_DIR" archive "$ADAPT_REF" | tar -C "$destination" -xf -
    fi
}

write_containerfile() {
    local destination="$1"
    cat >"$destination" <<'EOF'
FROM php:7.4-apache AS php-base

RUN sed -ri -e 's!/var/www/html!/var/www/html/public!g' /etc/apache2/sites-available/*.conf \
    && sed -ri -e 's!/var/www/!/var/www/html/public!g' /etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf \
    && a2enmod rewrite headers \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        git unzip libbz2-dev libfreetype6-dev libicu-dev libjpeg62-turbo-dev \
        libonig-dev libpng-dev libzip-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j"$(nproc)" bcmath bz2 gd intl mbstring pdo_mysql sockets zip \
    && rm -rf /var/lib/apt/lists/*

FROM node:18-bullseye AS frontend
WORKDIR /src
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
# master imports FixRequired with different casing than the tracked file.
RUN if [ -f resources/js/helpers/accessibility/fixRequired.js ] \
    && [ ! -e resources/js/helpers/accessibility/FixRequired.js ]; then \
        mv resources/js/helpers/accessibility/fixRequired.js \
           resources/js/helpers/accessibility/FixRequired.js; \
    fi
RUN npm run production

FROM php-base AS php-dependencies
COPY --from=composer:2.8 /usr/bin/composer /usr/local/bin/composer
WORKDIR /src
COPY . .
RUN --mount=type=secret,id=composer_auth,target=/run/secrets/composer_auth \
    COMPOSER_AUTH="$(cat /run/secrets/composer_auth)" \
    composer install --no-dev --no-interaction --prefer-dist --optimize-autoloader

FROM php-base
ENV APP_ENV=local \
    APP_DEBUG=true \
    LOG_CHANNEL=stderr
WORKDIR /var/www/html
COPY --from=php-dependencies /src /var/www/html
COPY --from=frontend /src/public /var/www/html/public
RUN mkdir -p storage/framework/cache storage/framework/sessions storage/framework/views storage/logs bootstrap/cache \
    && chown -R www-data:www-data storage bootstrap/cache
EXPOSE 80
CMD ["apache2-foreground"]
EOF
}

build_image() {
    local temporary_directory auth_file context containerfile
    temporary_directory="$(mktemp -d "${TMPDIR:-/tmp}/adapt-podman.XXXXXX")"
    BUILD_TEMPORARY_DIRECTORY="$temporary_directory"
    auth_file="$temporary_directory/composer-auth.json"
    context="$temporary_directory/context"
    containerfile="$temporary_directory/Containerfile"

    composer_auth_file "$auth_file"
    printf 'Staging %s without changing the worktree...\n' "$ADAPT_REF"
    stage_source "$context"
    if [[ "${SKIP_LICENSED_PDF_PARSER:-0}" == "1" ]]; then
        omit_licensed_pdf_parser "$context"
    fi
    write_containerfile "$containerfile"

    printf 'Building %s...\n' "$ADAPT_IMAGE"
    podman build \
        --secret "id=composer_auth,src=$auth_file" \
        --file "$containerfile" \
        --tag "$ADAPT_IMAGE" \
        "$context"
    cleanup_build_temporary_directory
}

ensure_network_and_volume() {
    podman network exists "$ADAPT_NETWORK" || podman network create "$ADAPT_NETWORK" >/dev/null
    podman volume exists "$ADAPT_DB_VOLUME" || podman volume create "$ADAPT_DB_VOLUME" >/dev/null
}

start_dependencies() {
    remove_container "$ADAPT_DB_CONTAINER"
    remove_container "$ADAPT_REDIS_CONTAINER"

    podman run -d \
        --name "$ADAPT_DB_CONTAINER" \
        --network "$ADAPT_NETWORK" \
        --network-alias mysql \
        -e "MYSQL_DATABASE=$ADAPT_DB_DATABASE" \
        -e "MYSQL_USER=$ADAPT_DB_USERNAME" \
        -e "MYSQL_PASSWORD=$ADAPT_DB_PASSWORD" \
        -e "MYSQL_ROOT_PASSWORD=$ADAPT_DB_ROOT_PASSWORD" \
        -v "$ADAPT_DB_VOLUME:/var/lib/mysql" \
        docker.io/library/mysql:8.0 >/dev/null

    podman run -d \
        --name "$ADAPT_REDIS_CONTAINER" \
        --network "$ADAPT_NETWORK" \
        --network-alias redis \
        docker.io/library/redis:7-alpine >/dev/null
}

wait_for_mysql() {
    local attempts=0
    printf 'Waiting for MySQL'
    while (( attempts < 60 )); do
        if podman exec "$ADAPT_DB_CONTAINER" mysqladmin ping \
            -h 127.0.0.1 -uroot "-p$ADAPT_DB_ROOT_PASSWORD" --silent >/dev/null 2>&1; then
            printf ' ready.\n'
            return
        fi
        ((attempts += 1))
        printf '.'
        sleep 2
    done
    printf '\n' >&2
    podman logs "$ADAPT_DB_CONTAINER" >&2 || true
    die "MySQL did not become ready within 120 seconds"
}

make_app_key() {
    require_command openssl
    printf 'base64:%s' "$(openssl rand -base64 32 | tr -d '\n')"
}

app_environment_args() {
    local app_key="$1"
    APP_ENV_ARGS=(
        -e "APP_NAME=LibreTexts ADAPT"
        -e "APP_ENV=local"
        -e "APP_KEY=$app_key"
        -e "APP_DEBUG=true"
        -e "APP_URL=http://localhost:$ADAPT_PORT"
        -e "LOG_CHANNEL=stderr"
        -e "DB_CONNECTION=mysql"
        -e "DB_HOST=mysql"
        -e "DB_PORT=3306"
        -e "DB_DATABASE=$ADAPT_DB_DATABASE"
        -e "DB_USERNAME=$ADAPT_DB_USERNAME"
        -e "DB_PASSWORD=$ADAPT_DB_PASSWORD"
        -e "REDIS_HOST=redis"
        -e "REDIS_PORT=6379"
        -e "CACHE_DRIVER=file"
        -e "QUEUE_CONNECTION=sync"
        -e "SESSION_DRIVER=file"
        -e "MAIL_MAILER=log"
        -e "JWT_SECRET=$app_key"
        -e "WEBWORK_JWT_SECRET=$app_key"
        -e "AWS_DEFAULT_REGION=us-east-1"
        -e "AWS_REGION=us-east-1"
        -e "XRAY_ENABLED="
        -e "XRAY_AWS_ACCESS_KEY_ID=local-disabled"
        -e "XRAY_AWS_SECRET_ACCESS_KEY=local-disabled"
    )
}

wait_for_application() {
    local attempts=0 url="http://localhost:$ADAPT_PORT/"
    require_command curl
    printf 'Waiting for ADAPT'
    while (( attempts < 30 )); do
        if curl --fail --silent --show-error --output /dev/null "$url" 2>/dev/null; then
            printf ' ready.\n'
            return
        fi
        ((attempts += 1))
        printf '.'
        sleep 2
    done
    printf '\n' >&2
    podman logs --tail 100 "$ADAPT_APP_CONTAINER" >&2 || true
    die "ADAPT did not return a successful HTTP response within 60 seconds"
}

setup_local_account() {
    local account_type="$1" require_developer="$2"
    local first_name last_name email password time_zone role

    first_name="$(yaml_value "$account_type.first_name")"
    last_name="$(yaml_value "$account_type.last_name")"
    email="$(yaml_value "$account_type.email")"
    password="$(yaml_value "$account_type.password")"
    time_zone="$(yaml_value "$account_type.time_zone")"
    role="$(yaml_value "$account_type.role")"

    [[ "$role" =~ ^[1-6]$ ]] || die "$account_type.role must be an integer from 1 through 6"
    [[ ${#password} -ge 8 ]] || die "$account_type.password must contain at least 8 characters"
    [[ "$password" != replace-with-* ]] || die "replace the example $account_type password in $ADAPT_LOCAL_CONFIG"

    podman exec \
        -e "LOCAL_ACCOUNT_TYPE=$account_type" \
        -e "LOCAL_ACCOUNT_FIRST_NAME=$first_name" \
        -e "LOCAL_ACCOUNT_LAST_NAME=$last_name" \
        -e "LOCAL_ACCOUNT_EMAIL=$email" \
        -e "LOCAL_ACCOUNT_PASSWORD=$password" \
        -e "LOCAL_ACCOUNT_TIME_ZONE=$time_zone" \
        -e "LOCAL_ACCOUNT_ROLE=$role" \
        -e "LOCAL_ACCOUNT_REQUIRE_DEVELOPER=$require_developer" \
        "$ADAPT_APP_CONTAINER" php artisan tinker --execute='
            $accountType = getenv("LOCAL_ACCOUNT_TYPE");
            $email = getenv("LOCAL_ACCOUNT_EMAIL");
            $user = App\User::where("email", $email)->first();
            $created = ! $user;
            if ($created) {
                $user = new App\User;
                $user->email = $email;
            }
            $user->first_name = getenv("LOCAL_ACCOUNT_FIRST_NAME");
            $user->last_name = getenv("LOCAL_ACCOUNT_LAST_NAME");
            $user->time_zone = getenv("LOCAL_ACCOUNT_TIME_ZONE");
            $user->role = (int) getenv("LOCAL_ACCOUNT_ROLE");
            if ($created || ! Illuminate\Support\Facades\Hash::check(getenv("LOCAL_ACCOUNT_PASSWORD"), $user->password)) {
                $user->password = bcrypt(getenv("LOCAL_ACCOUNT_PASSWORD"));
            }
            $user->save();
            $verb = $created ? "Created" : "Updated";
            echo "{$verb} local {$accountType} account: {$email} (user ID {$user->id})\n";
            if (getenv("LOCAL_ACCOUNT_REQUIRE_DEVELOPER") === "1" && ! $user->isDeveloper()) {
                fwrite(STDERR, "warning: user ID {$user->id} is not in the hard-coded ADAPT developer list.\n");
            }
            echo "Local {$accountType} account confirmed.\n";
        '
}

setup_local_accounts() {
    local developer_email instructor_email student_email

    container_running "$ADAPT_APP_CONTAINER" \
        || die "application container is not running; run '$ADAPT_COMMAND_NAME up' first"
    require_command python3

    developer_email="$(yaml_value developer.email)"
    instructor_email="$(yaml_value instructor.email)"
    student_email="$(yaml_value student.email)"
    [[ "$developer_email" != "$instructor_email" \
        && "$developer_email" != "$student_email" \
        && "$instructor_email" != "$student_email" ]] \
        || die "developer, instructor, and student emails must be different"

    setup_local_account developer 1
    setup_local_account instructor 0
    setup_local_account student 0
}

setup_test_fixtures() {
    local fixture_mode="${1:-reset}"
    local fixture_file instructor_email student_email container_fixture

    container_exists "$ADAPT_APP_CONTAINER" \
        || die "application container is not running; run '$ADAPT_COMMAND_NAME up' first"

    fixture_file="$REPO_ROOT/tests/e2e/setup_adapt_fixtures.php"
    container_fixture="/tmp/setup_adapt_fixtures.php"
    [[ -r "$fixture_file" ]] || die "fixture setup file not found: $fixture_file"

    setup_local_accounts
    instructor_email="$(yaml_value instructor.email)"
    student_email="$(yaml_value student.email)"

    printf 'Creating deterministic ADAPT test data...\n'
    podman cp "$fixture_file" "$ADAPT_APP_CONTAINER:$container_fixture"
    podman exec "$ADAPT_APP_CONTAINER" php "$container_fixture" \
        "$instructor_email" \
        "$student_email" \
        "http://localhost:$ADAPT_PORT" \
        "$fixture_mode"
}

start_application() {
    local app_key
    app_key="$(make_app_key)"
    app_environment_args "$app_key"
    remove_container "$ADAPT_APP_CONTAINER"

    printf 'Running database migrations...\n'
    podman run --rm \
        --network "$ADAPT_NETWORK" \
        "${APP_ENV_ARGS[@]}" \
        "$ADAPT_IMAGE" php artisan migrate --force

    podman run -d \
        --name "$ADAPT_APP_CONTAINER" \
        --network "$ADAPT_NETWORK" \
        "${APP_ENV_ARGS[@]}" \
        -p "$ADAPT_PORT:80" \
        "$ADAPT_IMAGE" >/dev/null

    wait_for_application
    printf '\nADAPT is running at http://localhost:%s\n' "$ADAPT_PORT"
    printf 'Follow startup output with: %s logs\n' "$ADAPT_COMMAND_NAME"
}

ensure_image() {
    if ! podman image exists "$ADAPT_IMAGE"; then
        build_image
    fi
}

start_environment() {
    ensure_network_and_volume
    start_dependencies
    wait_for_mysql
    start_application
}

ensure_environment_running() {
    if container_running "$ADAPT_APP_CONTAINER" \
        && container_running "$ADAPT_DB_CONTAINER" \
        && container_running "$ADAPT_REDIS_CONTAINER"; then
        wait_for_application
        return
    fi

    ensure_image
    start_environment
}

setup_test_environment() {
    local fixture_mode="${1:-ensure}"
    setup_test_fixtures "$fixture_mode"
}

down() {
    remove_container "$ADAPT_APP_CONTAINER"
    remove_container "$ADAPT_REDIS_CONTAINER"
    remove_container "$ADAPT_DB_CONTAINER"
    printf 'Containers removed; database volume %s was preserved.\n' "$ADAPT_DB_VOLUME"
}

clean() {
    remove_container "$ADAPT_APP_CONTAINER"
    remove_container "$ADAPT_REDIS_CONTAINER"
    remove_container "$ADAPT_DB_CONTAINER"
    podman image exists "$ADAPT_IMAGE" && podman rmi "$ADAPT_IMAGE" >/dev/null || true
    podman volume exists "$ADAPT_DB_VOLUME" && podman volume rm "$ADAPT_DB_VOLUME" >/dev/null || true
    podman network exists "$ADAPT_NETWORK" && podman network rm "$ADAPT_NETWORK" >/dev/null || true
    printf 'Containers, image, database volume, and network removed.\n'
}

status() {
    podman ps -a --filter "name=^${ADAPT_APP_CONTAINER}$" \
        --filter "name=^${ADAPT_DB_CONTAINER}$" \
        --filter "name=^${ADAPT_REDIS_CONTAINER}$"
    printf '\nApplication URL: http://localhost:%s\n' "$ADAPT_PORT"
}

main() {
    local action="${1:-up}"
    case "$action" in
        -h|--help|help)
            usage
            return
            ;;
        up|rebuild|reset|build|setup-account|setup-fixtures|down|clean|logs|status)
            ensure_podman
            ;;
        *)
            usage >&2
            die "unknown action: $action"
            ;;
    esac

    case "$action" in
        up|rebuild|reset|setup-account|setup-fixtures)
            require_local_config
            ;;
    esac

    case "$action" in
        up|rebuild)
            if [[ "$action" == "rebuild" ]] || ! podman image exists "$ADAPT_IMAGE"; then
                build_image
            else
                printf 'Using existing image %s (run `%s rebuild` to rebuild).\n' "$ADAPT_IMAGE" "$ADAPT_COMMAND_NAME"
            fi
            start_environment
            setup_test_environment ensure
            ;;
        reset)
            ensure_image
            remove_container "$ADAPT_APP_CONTAINER"
            remove_container "$ADAPT_REDIS_CONTAINER"
            remove_container "$ADAPT_DB_CONTAINER"
            podman volume exists "$ADAPT_DB_VOLUME" && podman volume rm "$ADAPT_DB_VOLUME" >/dev/null || true
            start_environment
            setup_test_environment reset
            ;;
        build)
            build_image
            ;;
        setup-account)
            ensure_environment_running
            setup_local_accounts
            ;;
        setup-fixtures)
            ensure_environment_running
            setup_test_fixtures reset
            ;;
        down)
            down
            ;;
        clean)
            clean
            ;;
        logs)
            podman logs --follow "$ADAPT_APP_CONTAINER"
            ;;
        status)
            status
            ;;
    esac
}

main "$@"
