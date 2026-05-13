#!/usr/bin/env bash
#
# start_rails_tmux.sh — open (or reuse) a tmux session with three panes laid out
# main-vertical: editor on the left, server top-right, auxiliary REPL bottom-right.
#
# Environment overrides:
#   TMUX_SESSION_NAME   Session name (default: sanitized repo basename)
#   TMUX_WINDOW_NAME    Window name (default: "app")
#   TMUX_SERVER_CMD     Command for the server pane (default: bin/dev if present, else bin/rails server)
#   TMUX_AUX_CMD        Command for the auxiliary pane (default: bin/rails console)
#   TMUX_EDITOR_CMD     Command for the editor pane (default: hx)
#   TMUX_ATTACH         "1" to attach/switch after layout (default), "0" to stay detached
#   TMUX_RESET          "1" to kill the existing session before recreating it (default "0")

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
EDITOR_CMD="${TMUX_EDITOR_CMD:-hx}"

sanitize_session_name() {
  basename "${REPO_ROOT}" | tr -c '[:alnum:]_-' '_'
}

SESSION_NAME="${TMUX_SESSION_NAME:-$(sanitize_session_name)}"
WINDOW_NAME="${TMUX_WINDOW_NAME:-app}"
AUX_CMD="${TMUX_AUX_CMD:-bin/rails console}"
ATTACH_SESSION="${TMUX_ATTACH:-1}"
RESET_SESSION="${TMUX_RESET:-0}"

if [[ -x "${REPO_ROOT}/bin/dev" ]]; then
  SERVER_CMD="${TMUX_SERVER_CMD:-bin/dev}"
else
  SERVER_CMD="${TMUX_SERVER_CMD:-bin/rails server}"
fi

if ! command -v tmux >/dev/null 2>&1; then
  echo "tmux is not installed." >&2
  exit 1
fi

attach_or_switch() {
  if [[ "${ATTACH_SESSION}" != "1" ]]; then
    return
  fi

  tmux select-window -t "${SESSION_NAME}:${WINDOW_NAME}"

  if [[ -n "${TMUX:-}" ]]; then
    tmux switch-client -t "${SESSION_NAME}"
  else
    # exec replaces this shell; nothing runs after this line.
    exec tmux attach-session -t "${SESSION_NAME}"
  fi
}

window_exists() {
  tmux list-windows -t "${SESSION_NAME}" -F '#W' 2>/dev/null | grep -Fxq "${WINDOW_NAME}"
}

first_pane_id() {
  tmux list-panes -t "${SESSION_NAME}:${WINDOW_NAME}" -F '#{pane_id}' | head -n 1
}

pane_count() {
  tmux display-message -p -t "${SESSION_NAME}:${WINDOW_NAME}" '#{window_panes}'
}

pane_current_command() {
  tmux display-message -p -t "$1" '#{pane_current_command}'
}

pane_is_shell() {
  case "$(pane_current_command "$1")" in
    bash|zsh|sh|dash|fish|ksh|ash)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

# Wait briefly for a freshly-split pane's shell to initialize before sending keys.
# Heavy shell rc files can leave the pane unable to receive input for a few ms.
wait_for_shell_ready() {
  local pane_id="$1"
  local attempts=0
  while (( attempts < 20 )); do
    if pane_is_shell "${pane_id}"; then
      return 0
    fi
    sleep 0.05
    attempts=$((attempts + 1))
  done
  return 1
}

start_in_shell_pane() {
  local pane_id="$1"
  local command="$2"

  if pane_is_shell "${pane_id}"; then
    tmux send-keys -t "${pane_id}" "${command}" C-m
  fi
}

# Layout assumption: main-vertical places one pane on the left and stacks the
# remaining panes on the right. The two helpers below select the topmost and
# bottommost panes among those sharing the largest pane_left coordinate.
top_right_pane_id() {
  tmux list-panes -t "${SESSION_NAME}:${WINDOW_NAME}" -F '#{pane_id} #{pane_left} #{pane_top}' \
    | awk '
      BEGIN { best_left = -1; best_top = -1 }
      {
        if (best_left < 0 || $2 > best_left || ($2 == best_left && $3 < best_top)) {
          best_id = $1
          best_left = $2
          best_top = $3
        }
      }
      END { print best_id }
    '
}

bottom_right_pane_id() {
  tmux list-panes -t "${SESSION_NAME}:${WINDOW_NAME}" -F '#{pane_id} #{pane_left} #{pane_top}' \
    | awk '
      BEGIN { best_left = -1; best_top = -1 }
      {
        if (best_left < 0 || $2 > best_left || ($2 == best_left && $3 > best_top)) {
          best_id = $1
          best_left = $2
          best_top = $3
        }
      }
      END { print best_id }
    '
}

if [[ "${RESET_SESSION}" == "1" ]] && tmux has-session -t "${SESSION_NAME}" 2>/dev/null; then
  tmux kill-session -t "${SESSION_NAME}"
fi

created_window=0

if tmux has-session -t "${SESSION_NAME}" 2>/dev/null; then
  if ! window_exists; then
    editor_pane="$(tmux new-window -d -P -F '#{pane_id}' -t "${SESSION_NAME}" -n "${WINDOW_NAME}" -c "${REPO_ROOT}")"
    created_window=1
  else
    editor_pane="$(first_pane_id)"
  fi
else
  editor_pane="$(tmux new-session -d -P -F '#{pane_id}' -s "${SESSION_NAME}" -n "${WINDOW_NAME}" -c "${REPO_ROOT}")"
  created_window=1
fi

if [[ "${created_window}" == "1" ]]; then
  wait_for_shell_ready "${editor_pane}" || true
  start_in_shell_pane "${editor_pane}" "${EDITOR_CMD}"
fi

current_pane_count="$(pane_count)"

if [[ "${current_pane_count}" -lt 2 ]]; then
  server_pane="$(tmux split-window -h -P -F '#{pane_id}' -t "${editor_pane}" -c "${REPO_ROOT}")"
  wait_for_shell_ready "${server_pane}" || true
  start_in_shell_pane "${server_pane}" "${SERVER_CMD}"
else
  server_pane="$(top_right_pane_id)"
fi

current_pane_count="$(pane_count)"

if [[ "${current_pane_count}" -lt 3 ]]; then
  aux_pane="$(tmux split-window -v -P -F '#{pane_id}' -t "${server_pane}" -c "${REPO_ROOT}")"
  wait_for_shell_ready "${aux_pane}" || true
  start_in_shell_pane "${aux_pane}" "${AUX_CMD}"
else
  aux_pane="$(bottom_right_pane_id)"
fi

# Re-issue each command if its pane has fallen back to a shell prompt
# (e.g. the server crashed). pane_is_shell guards no-op for live processes.
start_in_shell_pane "${editor_pane}" "${EDITOR_CMD}"
start_in_shell_pane "${server_pane}" "${SERVER_CMD}"
start_in_shell_pane "${aux_pane}" "${AUX_CMD}"

tmux select-layout -t "${SESSION_NAME}:${WINDOW_NAME}" main-vertical
tmux select-pane -t "$(first_pane_id)"

attach_or_switch
