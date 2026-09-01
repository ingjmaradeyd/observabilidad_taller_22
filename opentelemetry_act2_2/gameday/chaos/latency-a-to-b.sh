#!/usr/bin/env bash

set -Eeuo pipefail

TARGET_HOST="${TARGET_HOST:-service-b-chaos}"
LATENCY="${LATENCY:-800ms}"
JITTER="${JITTER:-100ms}"
DURATION_SECONDS="${DURATION_SECONDS:-120}"
INTERFACE="${INTERFACE:-}"
STATE_FILE="${STATE_FILE:-/tmp/gameday-latency-interface}"
IP_BIN="${IP_BIN:-ip}"
TC_BIN="${TC_BIN:-tc}"
GETENT_BIN="${GETENT_BIN:-getent}"
ACTIVE_INTERFACE=""

resolve_target_ip() {
  local target_ip

  target_ip="$(${GETENT_BIN} ahostsv4 "${TARGET_HOST}" | awk 'NR == 1 { print $1 }')"
  if [[ -z "${target_ip}" ]]; then
    echo "Could not resolve ${TARGET_HOST}." >&2
    return 1
  fi

  printf '%s\n' "${target_ip}"
}

resolve_route_interface() {
  local target_ip route_interface

  target_ip="$(resolve_target_ip)"
  route_interface="$(${IP_BIN} route get "${target_ip}" | awk '{ for (i = 1; i <= NF; i++) if ($i == "dev") { print $(i + 1); exit } }')"
  if [[ -z "${route_interface}" ]]; then
    echo "Could not determine the interface used to reach ${TARGET_HOST} (${target_ip})." >&2
    return 1
  fi

  printf '%s\n' "${route_interface}"
}

interface_for_action() {
  if [[ -n "${INTERFACE}" ]]; then
    printf '%s\n' "${INTERFACE}"
  elif [[ -s "${STATE_FILE}" ]]; then
    cat "${STATE_FILE}"
  else
    resolve_route_interface
  fi
}

remove_netem() {
  local route_interface="$1"

  if ${TC_BIN} qdisc show dev "${route_interface}" | grep -q ' netem '; then
    ${TC_BIN} qdisc del dev "${route_interface}" root
    echo "Removed netem from ${route_interface}."
  else
    echo "No netem rule found on ${route_interface}."
  fi

  rm -f "${STATE_FILE}"
}

run_experiment() {
  local route_interface

  if [[ ! "${DURATION_SECONDS}" =~ ^[0-9]+$ ]]; then
    echo "DURATION_SECONDS must be a non-negative integer." >&2
    return 2
  fi

  route_interface="$(resolve_route_interface)"
  ACTIVE_INTERFACE="${route_interface}"
  printf '%s\n' "${route_interface}" > "${STATE_FILE}"
  trap 'remove_netem "${ACTIVE_INTERFACE}"' EXIT
  trap 'exit 130' HUP INT TERM

  ${TC_BIN} qdisc replace dev "${route_interface}" root netem delay "${LATENCY}" "${JITTER}"
  echo "Injected ${LATENCY} ±${JITTER} toward ${TARGET_HOST} on ${route_interface} for ${DURATION_SECONDS}s."

  sleep "${DURATION_SECONDS}"
}

show_status() {
  local route_interface

  route_interface="$(interface_for_action)"
  echo "Interface for ${TARGET_HOST}: ${route_interface}"
  ${TC_BIN} qdisc show dev "${route_interface}"
}

cleanup_experiment() {
  local route_interface

  route_interface="$(interface_for_action)"
  remove_netem "${route_interface}"
}

usage() {
  echo "Usage: $0 {run|status|cleanup}" >&2
}

case "${1:-}" in
  run)
    run_experiment
    ;;
  status)
    show_status
    ;;
  cleanup)
    cleanup_experiment
    ;;
  *)
    usage
    exit 2
    ;;
esac
