#!/usr/bin/env bash

set -u
set -o pipefail

readonly project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
readonly script_under_test="$project_root/scripts/aws/configure_cost_budget.sh"

passed=0
failed=0

pass() {
  passed=$((passed + 1))
  printf 'PASS: %s\n' "$1"
}

fail() {
  failed=$((failed + 1))
  printf 'FAIL: %s\n' "$1" >&2
}

assert_contains() {
  local output="$1"
  local expected="$2"
  [[ "$output" == *"$expected"* ]]
}

assert_not_contains() {
  local output="$1"
  local unexpected="$2"
  [[ "$output" != *"$unexpected"* ]]
}

create_aws_stub() {
  local destination="$1"

  cat > "$destination" <<'STUB'
#!/usr/bin/env bash

set -u

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile)
      shift 2
      ;;
    --no-cli-pager|--no-cli-auto-prompt)
      shift
      ;;
    *)
      break
      ;;
  esac
done

service="${1:-}"
operation="${2:-}"
shift 2

if [[ "$service:$operation" == "sts:get-caller-identity" ]]; then
  printf '%s\n' "$AWS_STUB_ACCOUNT_ID"
  exit 0
fi

if [[ "$service:$operation" == "budgets:describe-budget" ]]; then
  case "$AWS_STUB_SCENARIO" in
    create|terminate)
      echo "An error occurred (NotFoundException) when calling DescribeBudget" >&2
      exit 254
      ;;
    existing)
      printf 'observabilidad-lab-mensual\t20\tUSD\tMONTHLY\tCOST\n'
      exit 0
      ;;
    unexpected)
      echo "An error occurred (AccessDeniedException) when calling DescribeBudget" >&2
      exit 254
      ;;
  esac
fi

if [[ "$service:$operation" == "budgets:create-budget" ]]; then
  account_id=""
  budget_json=""
  notifications_json=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --account-id)
        account_id="$2"
        shift 2
        ;;
      --budget)
        budget_json="$2"
        shift 2
        ;;
      --notifications-with-subscribers)
        notifications_json="$2"
        shift 2
        ;;
      *)
        shift
        ;;
    esac
  done

  [[ "$account_id" == "$AWS_STUB_ACCOUNT_ID" ]] || exit 90
  [[ "$budget_json" == *'"BudgetName":"observabilidad-lab-mensual"'* ]] || exit 91
  [[ "$budget_json" == *'"Amount":"20"'* ]] || exit 92
  [[ "$budget_json" == *'"Unit":"USD"'* ]] || exit 93
  [[ "$budget_json" == *'"TimeUnit":"MONTHLY"'* ]] || exit 94
  [[ "$budget_json" == *'"BudgetType":"COST"'* ]] || exit 95
  [[ "$notifications_json" == *'"Threshold":50'* ]] || exit 96
  [[ "$notifications_json" == *'"Threshold":80'* ]] || exit 97
  [[ "$notifications_json" == *'"Threshold":100'* ]] || exit 98
  [[ "$notifications_json" == *'"NotificationType":"ACTUAL"'* ]] || exit 99
  [[ "$notifications_json" == *'"SubscriptionType":"EMAIL"'* ]] || exit 100
  [[ "$notifications_json" == *'"Address":"'"$AWS_STUB_EMAIL"'"'* ]] || exit 101

  if [[ "$AWS_STUB_SCENARIO" == "terminate" ]]; then
    kill -TERM "$PPID"
    exit 0
  fi

  printf 'created\n' > "$AWS_STUB_MARKER"
  exit 0
fi

exit 89
STUB

  chmod +x "$destination"
}

run_script() {
  local email="$1"
  printf '%s\n' "$email" | \
    AWS_CLI="$aws_stub" \
    AWS_STUB_SCENARIO="$scenario" \
    AWS_STUB_ACCOUNT_ID="$account_id" \
    AWS_STUB_EMAIL="$email" \
    AWS_STUB_MARKER="$marker" \
    "$script_under_test" --profile test-profile 2>&1
}

test_successful_creation() {
  scenario="create"
  rm -f "$marker"

  local output status=0
  output="$(run_script "$test_email")" || status=$?

  if [[ "$status" -eq 0 ]] &&
    [[ -f "$marker" ]] &&
    assert_contains "$output" "Presupuesto creado correctamente." &&
    assert_contains "$output" "Alertas de costo real: 50 %, 80 % y 100 %."; then
    pass "creación correcta"
  else
    fail "creación correcta"
  fi
}

test_existing_budget() {
  scenario="existing"
  rm -f "$marker"

  local output status=0
  output="$(run_script "$test_email")" || status=$?

  if [[ "$status" -eq 0 ]] &&
    [[ ! -e "$marker" ]] &&
    assert_contains "$output" "El presupuesto ya existe; no se realizaron cambios." &&
    assert_contains "$output" "Nombre: observabilidad-lab-mensual"; then
    pass "presupuesto existente sin cambios"
  else
    fail "presupuesto existente sin cambios"
  fi
}

test_unexpected_error() {
  scenario="unexpected"
  rm -f "$marker"

  local output status=0
  output="$(run_script "$test_email")" || status=$?

  if [[ "$status" -ne 0 ]] &&
    [[ ! -e "$marker" ]] &&
    assert_contains "$output" "ERROR: No fue posible comprobar si el presupuesto ya existe."; then
    pass "error inesperado aborta"
  else
    fail "error inesperado aborta"
  fi
}

test_sanitized_output() {
  scenario="create"
  rm -f "$marker"

  local output status=0
  output="$(run_script "$test_email")" || status=$?

  if [[ "$status" -eq 0 ]] &&
    assert_not_contains "$output" "$test_email" &&
    assert_not_contains "$output" "$account_id"; then
    pass "salida no expone correo ni AccountId"
  else
    fail "salida no expone correo ni AccountId"
  fi
}

test_termination_during_creation() {
  scenario="terminate"
  rm -f "$marker" "$after_script_marker"

  local output status=0
  output="$(run_script "$test_email" && printf 'executed\n' > "$after_script_marker")" || status=$?

  if [[ "$status" -eq 143 ]] &&
    [[ ! -e "$marker" ]] &&
    [[ ! -e "$after_script_marker" ]] &&
    assert_not_contains "$output" "Presupuesto creado correctamente."; then
    pass "SIGTERM aborta sin continuar"
  else
    fail "SIGTERM aborta sin continuar"
  fi
}

tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/budget-script-test.XXXXXX")"
trap 'rm -rf "$tmp_dir"' EXIT INT TERM

aws_stub="$tmp_dir/aws"
marker="$tmp_dir/created.marker"
after_script_marker="$tmp_dir/after-script.marker"
account_id="123456789012"
test_email="student@example.edu"
scenario=""

create_aws_stub "$aws_stub"

test_successful_creation
test_existing_budget
test_unexpected_error
test_sanitized_output
test_termination_during_creation

printf '\nResultado: %d aprobadas, %d fallidas.\n' "$passed" "$failed"
[[ "$failed" -eq 0 ]]
