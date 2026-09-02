#!/usr/bin/env bash

set -u
set -o pipefail

profile="${AWS_PROFILE:-observabilidad-lab}"
region="${AWS_REGION:-${AWS_DEFAULT_REGION:-us-east-1}}"
aws_cli="${AWS_CLI:-}"

available=0
not_enabled=0
denied=0
errors=0
last_status=""

usage() {
  cat <<'EOF'
Uso: check_sandbox_capabilities.sh [--profile PERFIL] [--region REGION]

Audita capacidades de un sandbox AWS con operaciones de solo lectura.
No crea, modifica ni elimina recursos.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile)
      [[ $# -ge 2 ]] || { echo "Falta el valor de --profile" >&2; exit 64; }
      profile="$2"
      shift 2
      ;;
    --region)
      [[ $# -ge 2 ]] || { echo "Falta el valor de --region" >&2; exit 64; }
      region="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Argumento desconocido: $1" >&2
      usage >&2
      exit 64
      ;;
  esac
done

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
  echo "ERROR: AWS_CLI no apunta a un ejecutable: $aws_cli" >&2
  exit 127
fi

tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/aws-sandbox-audit.XXXXXX")"
trap 'rm -rf "$tmp_dir"' EXIT INT TERM

extract_error_code() {
  local error_file="$1"
  local code

  code="$(sed -n 's/.*(\([^)]*\)) when calling.*/\1/p' "$error_file" | head -n 1)"
  if [[ -z "$code" ]]; then
    code="CLI_ERROR"
  fi
  printf '%s' "$code"
}

classify_error() {
  local error_file="$1"

  if grep -Eqi 'AccessDenied|UnauthorizedOperation|not authorized|ForbiddenException' "$error_file"; then
    printf 'DENEGADO'
  elif grep -Eqi 'SubscriptionRequired|NotSubscribed|not subscribed|not enabled|is not enabled|InvalidAccessException|ResourceNotFoundException|AccountNotFoundException' "$error_file"; then
    printf 'NO HABILITADO'
  else
    printf 'ERROR'
  fi
}

print_row() {
  local label="$1"
  local status="$2"
  local detail="$3"

  printf '%-34s | %-14s | %s\n' "$label" "$status" "$detail"
}

run_check() {
  local label="$1"
  shift
  local error_file="$tmp_dir/error.log"
  local status
  local detail

  : > "$error_file"
  if "$aws_cli" \
    --profile "$profile" \
    --region "$region" \
    --no-cli-pager \
    --no-cli-auto-prompt \
    --cli-connect-timeout 5 \
    --cli-read-timeout 10 \
    "$@" >/dev/null 2>"$error_file"; then
    status="DISPONIBLE"
    detail="API accesible"
    available=$((available + 1))
  else
    status="$(classify_error "$error_file")"
    detail="$(extract_error_code "$error_file")"
    case "$status" in
      "NO HABILITADO") not_enabled=$((not_enabled + 1)) ;;
      "DENEGADO") denied=$((denied + 1)) ;;
      *) errors=$((errors + 1)) ;;
    esac
  fi

  last_status="$status"
  print_row "$label" "$status" "$detail"
}

printf 'Auditoría de capacidades del sandbox AWS\n'
printf 'Fecha UTC: %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
printf 'Perfil: %s\n' "$profile"
printf 'Región: %s\n' "$region"
printf 'AWS CLI: %s\n\n' "$("$aws_cli" --version 2>&1 | awk '{print $1}')"
printf '%-34s | %-14s | %s\n' "CAPACIDAD" "ESTADO" "DETALLE"
printf '%-34s-+-%-14s-+-%s\n' "----------------------------------" "--------------" "----------------"

run_check "Identidad STS" sts get-caller-identity
if [[ "$last_status" != "DISPONIBLE" ]]; then
  echo
  echo "La autenticación falló; se cancela la auditoría para evitar resultados engañosos." >&2
  exit 2
fi

run_check "ECS / Service Connect" ecs list-account-settings --effective-settings
run_check "ECR" ecr describe-repositories --max-results 20
run_check "RDS" rds describe-db-instances --max-records 20
run_check "Cloud Map" servicediscovery list-namespaces --max-results 20
run_check "VPC Flow Logs" ec2 describe-flow-logs --max-results 20
run_check "Security Hub" securityhub describe-hub
run_check "DevOps Guru" devops-guru describe-account-health
run_check "CloudWatch Logs" logs describe-log-groups --limit 20
run_check "CloudWatch Dashboards" cloudwatch list-dashboards --max-items 20
run_check "X-Ray" xray get-groups
run_check "Service Quotas (ECS)" service-quotas list-service-quotas --service-code ecs --max-results 1

echo
printf 'Resumen: DISPONIBLE=%d | NO HABILITADO=%d | DENEGADO=%d | ERROR=%d\n' \
  "$available" "$not_enabled" "$denied" "$errors"
echo "La auditoría no creó, modificó ni eliminó recursos AWS."

if [[ "$errors" -gt 0 ]]; then
  exit 1
fi
