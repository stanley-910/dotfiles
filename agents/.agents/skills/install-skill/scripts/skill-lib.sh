#!/usr/bin/env bash

set -euo pipefail

command -v realpath >/dev/null 2>&1 || {
  printf 'ERROR realpath is not available on PATH\n' >&2
  exit 1
}
SKILL_LIB_PATH=$(realpath "${BASH_SOURCE[0]}")
readonly SKILL_LIB_PATH
SKILL_TOOL_ROOT="$(cd -- "$(dirname -- "$SKILL_LIB_PATH")/.." && pwd -P)"
readonly SKILL_TOOL_ROOT
DOTFILES_ROOT="$(cd -- "$SKILL_TOOL_ROOT/../../../.." && pwd -P)"
readonly DOTFILES_ROOT
readonly SHARED_SOURCE_ROOT="$DOTFILES_ROOT/agents/.agents/skills"
readonly CLAUDE_SOURCE_ROOT="$DOTFILES_ROOT/claude/.claude/skills"
readonly HUB_ROOT="$HOME/.agents/skills"
readonly CLAUDE_TARGET_ROOT="$HOME/.claude/skills"
readonly PI_TARGET_ROOT="$HOME/.config/pi/agent/skills"

skill_usage_error() {
  printf 'ERROR %s\n' "$*" >&2
  return 2
}

skill_die() {
  printf 'ERROR %s\n' "$*" >&2
  exit 1
}

skill_validate_name() {
  local name=$1

  if [[ ! $name =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
    skill_usage_error "invalid skill name '$name'; use lowercase letters, numbers, and single hyphens"
    return 2
  fi
}

skill_source_dir() {
  local scope=$1
  local name=$2

  case $scope in
    shared) printf '%s/%s\n' "$SHARED_SOURCE_ROOT" "$name" ;;
    claude) printf '%s/%s\n' "$CLAUDE_SOURCE_ROOT" "$name" ;;
    *) skill_usage_error "unknown scope '$scope'; expected shared or claude" ;;
  esac
}

skill_frontmatter_name() {
  local skill_file=$1
  local value

  value=$(awk '
    NR == 1 {
      if ($0 != "---") exit 2
      in_frontmatter = 1
      next
    }
    in_frontmatter && $0 == "---" { exit }
    in_frontmatter && $0 ~ /^name:[[:space:]]*/ {
      sub(/^name:[[:space:]]*/, "")
      print
      found = 1
      exit
    }
    END { if (!found) exit 3 }
  ' "$skill_file") || return 1

  value=${value%$'\r'}
  value=${value#\"}
  value=${value%\"}
  value=${value#\'}
  value=${value%\'}
  printf '%s\n' "$value"
}

skill_parse_common_args() {
  SKILL_SCOPE=shared
  SKILL_FORCE=0
  SKILL_NAME=

  while (($#)); do
    case $1 in
      --scope)
        (($# >= 2)) || {
          skill_usage_error '--scope requires shared or claude'
          return 2
        }
        SKILL_SCOPE=$2
        shift 2
        ;;
      --scope=*)
        SKILL_SCOPE=${1#*=}
        shift
        ;;
      --force)
        SKILL_FORCE=1
        shift
        ;;
      -h|--help)
        return 64
        ;;
      --)
        shift
        if (($#)); then
          SKILL_NAME=$1
          shift
        fi
        break
        ;;
      -*)
        skill_usage_error "unknown option '$1'"
        return 2
        ;;
      *)
        if [[ -n $SKILL_NAME ]]; then
          skill_usage_error 'expected exactly one skill name'
          return 2
        fi
        SKILL_NAME=$1
        shift
        ;;
    esac
  done

  if (($#)); then
    skill_usage_error 'expected exactly one skill name'
    return 2
  fi
  if [[ $SKILL_SCOPE != shared && $SKILL_SCOPE != claude ]]; then
    skill_usage_error "unknown scope '$SKILL_SCOPE'; expected shared or claude"
    return 2
  fi
  if [[ -z $SKILL_NAME ]]; then
    skill_usage_error 'missing skill name'
    return 2
  fi
  skill_validate_name "$SKILL_NAME"
}
