#!/usr/bin/env bash

set +x
set -u
set -o pipefail

readonly budget_name="observabilidad-lab-mensual"
readonly budget_limit="20"
readonly budget_unit="USD"
readonly budget_period="MONTHLY"
readonly budget_type="COST"

profile="${AWS_PROFILE:-observabilidad-lab}"
aws_cli="${AWS_CLI:-}"
subscriber_email=""
tmp_dir=""

usage() {
  cat <<'EOF'
Uso: configure_cost_budget.sh [--profile PERFIL]

Crea un presupuesto AWS Budgets mensual de USD 20 llamado
observabilidad-lab-mensual, con alertas de costo real al 50 %, 80 % y 100 %.

El correo suscriptor se solicita sin eco y solo se envía a AWS; el script no lo
guarda en archivos ni lo muestra en la salida. Si el presupuesto ya existe, se
muestra un resumen sanitizado y no se realizan cambios.

Rollback manual (este script nunca lo ejecuta):
  1. Obtenga el AccountId con AWS STS para el perfil correspondiente.
  2. Ejecute:
     aws --profile PERFIL budgets delete-budget \
       --account-id ACCOUNT_ID \
       --budget-name observabilidad-lab-mensual
EOF
}

fail_usage() {
  echo "$1" >&2
  usage >&2
  exit 64
}

parse_arguments() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --profile)
        [[ $# -ge 2 && -n "$2" ]] || fail_usage "Falta el valor de --profile."
        profile="$2"
        shift 2
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        fail_usage "Argumento desconocido: $1"
        ;;
    esac
  done
}

resolve_aws_cli() {
  if [[ -z "$aws_cli" ]]; then
    if command -v aws >/dev/null 2>&1; then
      aws_cli="$(command -v aws)"
    elif [[ -x "$HOME/.local/bin/aws" ]]; then
      aws_cli="$HOME/.local/bin/aws"
    else
      echo "ERROR: AWS CLI no está disponible." >&2
      exit 127
    fi
  fi

  if [[ ! -x "$aws_cli" ]]; then
    echo "ERROR: AWS_CLI no apunta a un ejecutable válido." >&2
    exit 127
  fi
}

initialize_temporary_storage() {
  umask 077
  tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/aws-budget.XXXXXX")" || {
    echo "ERROR: No fue posible crear almacenamiento temporal seguro." >&2
    exit 1
  }
  trap cleanup_temporary_storage EXIT
  trap 'terminate_after_signal 130' INT
  trap 'terminate_after_signal 143' TERM
}

cleanup_temporary_storage() {
  if [[ -n "$tmp_dir" && -d "$tmp_dir" ]]; then
    rm -rf "$tmp_dir"
  fi
}

terminate_after_signal() {
  local exit_code="$1"

  trap - EXIT INT TERM
  cleanup_temporary_storage
  exit "$exit_code"
}

is_valid_email() {
  local candidate="$1"
  [[ "$candidate" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]
}

read_subscriber_email() {
  while true; do
    printf 'Correo institucional para las alertas (entrada oculta): ' >&2
    if ! IFS= read -r -s subscriber_email; then
      printf '\nERROR: No se pudo leer el correo institucional.\n' >&2
      exit 64
    fi
    printf '\n' >&2

    if is_valid_email "$subscriber_email"; then
      return
    fi

    echo "Correo inválido. Ingrese una dirección institucional válida." >&2
  done
}

run_aws() {
  AWS_CLI_HISTORY_FILE=/dev/null "$aws_cli" \
    --profile "$profile" \
    --no-cli-pager \
    --no-cli-auto-prompt \
    "$@"
}

get_account_id() {
  local account_id

  if ! account_id="$(run_aws sts get-caller-identity --query Account --output text 2>/dev/null)"; then
    echo "ERROR: No fue posible obtener el AccountId mediante AWS STS." >&2
    exit 1
  fi

  if [[ ! "$account_id" =~ ^[0-9]{12}$ ]]; then
    echo "ERROR: AWS STS devolvió un AccountId con formato inesperado." >&2
    exit 1
  fi

  printf '%s' "$account_id"
}

print_existing_budget() {
  local summary="$1"
  local existing_name existing_limit existing_unit existing_period existing_type

  IFS=$'\t' read -r \
    existing_name existing_limit existing_unit existing_period existing_type <<< "$summary"

  echo "El presupuesto ya existe; no se realizaron cambios."
  printf 'Nombre: %s\n' "$existing_name"
  printf 'Límite: %s\n' "$existing_limit"
  printf 'Unidad: %s\n' "$existing_unit"
  printf 'Período: %s\n' "$existing_period"
  printf 'Tipo: %s\n' "$existing_type"
}

budget_exists() {
  local account_id="$1"
  local describe_result error_file="$tmp_dir/describe-budget.error"

  if describe_result="$(run_aws budgets describe-budget \
    --account-id "$account_id" \
    --budget-name "$budget_name" \
    --query 'Budget.[BudgetName,BudgetLimit.Amount,BudgetLimit.Unit,TimeUnit,BudgetType]' \
    --output text 2>"$error_file")"; then
    print_existing_budget "$describe_result"
    return 0
  fi

  if grep -q 'NotFoundException' "$error_file"; then
    return 1
  fi

  echo "ERROR: No fue posible comprobar si el presupuesto ya existe." >&2
  exit 1
}

create_budget() {
  local account_id="$1"
  local budget_json notifications_json

  budget_json='{"BudgetName":"observabilidad-lab-mensual","BudgetLimit":{"Amount":"20","Unit":"USD"},"TimeUnit":"MONTHLY","BudgetType":"COST"}'
  printf -v notifications_json '%s' \
    '[{"Notification":{"NotificationType":"ACTUAL","ComparisonOperator":"GREATER_THAN","Threshold":50,"ThresholdType":"PERCENTAGE"},"Subscribers":[{"SubscriptionType":"EMAIL","Address":"'"$subscriber_email"'"}]},{"Notification":{"NotificationType":"ACTUAL","ComparisonOperator":"GREATER_THAN","Threshold":80,"ThresholdType":"PERCENTAGE"},"Subscribers":[{"SubscriptionType":"EMAIL","Address":"'"$subscriber_email"'"}]},{"Notification":{"NotificationType":"ACTUAL","ComparisonOperator":"GREATER_THAN","Threshold":100,"ThresholdType":"PERCENTAGE"},"Subscribers":[{"SubscriptionType":"EMAIL","Address":"'"$subscriber_email"'"}]}]'

  if ! run_aws budgets create-budget \
    --account-id "$account_id" \
    --budget "$budget_json" \
    --notifications-with-subscribers "$notifications_json" \
    >/dev/null 2>&1; then
    echo "ERROR: AWS rechazó la creación del presupuesto. Revise permisos y configuración del perfil." >&2
    exit 1
  fi
}

print_created_budget() {
  echo "Presupuesto creado correctamente."
  printf 'Nombre: %s\n' "$budget_name"
  printf 'Límite: %s\n' "$budget_limit"
  printf 'Unidad: %s\n' "$budget_unit"
  printf 'Período: %s\n' "$budget_period"
  printf 'Tipo: %s\n' "$budget_type"
  echo "Alertas de costo real: 50 %, 80 % y 100 %."
}

main() {
  local account_id

  parse_arguments "$@"
  resolve_aws_cli
  initialize_temporary_storage
  read_subscriber_email
  account_id="$(get_account_id)"

  if budget_exists "$account_id"; then
    exit 0
  fi

  create_budget "$account_id"
  print_created_budget
}

main "$@"
