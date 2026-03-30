#!/usr/bin/env bash

# Collect RSpec test descriptions and metadata for spec validation.
#
# This script runs RSpec in dry-run mode and extracts test descriptions,
# file paths, and requirement metadata tags. Output is JSON for easy
# parsing by the sdd:validate command.
#
# Usage: ./collect-test-descriptions.sh [OPTIONS]
#
# OPTIONS:
#   --json              Output in JSON format (default)
#   --requirement TAG   Filter tests by requirement metadata tag (e.g., "FR-001")
#   --help, -h          Show help message
#
# OUTPUTS:
#   JSON array of test descriptions with file paths and metadata.
#
# PREREQUISITES:
#   - bundle exec rspec must be available
#   - RSpec must be configured in the project

set -e

# Parse command line arguments
JSON_MODE=true
REQUIREMENT_FILTER=""

for arg in "$@"; do
    case "$arg" in
        --json)
            JSON_MODE=true
            ;;
        --requirement)
            shift
            REQUIREMENT_FILTER="$1"
            ;;
        --help|-h)
            cat << 'EOF'
Usage: collect-test-descriptions.sh [OPTIONS]

Collect RSpec test descriptions and metadata for spec validation.

OPTIONS:
  --json              Output in JSON format (default)
  --requirement TAG   Filter tests by requirement tag (e.g., "FR-001")
  --help, -h          Show this help message

EXAMPLES:
  # Collect all test descriptions
  ./collect-test-descriptions.sh

  # Filter to a specific requirement
  ./collect-test-descriptions.sh --requirement FR-001

EOF
            exit 0
            ;;
    esac
done

# Source common functions
SCRIPT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

REPO_ROOT=$(get_repo_root)
cd "$REPO_ROOT"

# Check if RSpec is available
if ! bundle exec rspec --version >/dev/null 2>&1; then
    echo '{"error":"RSpec not available. Run bundle install first.","tests":[]}' >&2
    exit 1
fi

# Build rspec command
RSPEC_CMD="bundle exec rspec --dry-run --format json"

if [[ -n "$REQUIREMENT_FILTER" ]]; then
    RSPEC_CMD="$RSPEC_CMD --tag requirement:$REQUIREMENT_FILTER"
fi

# Run RSpec dry-run and capture output
# --dry-run does not execute tests, only collects descriptions
RSPEC_OUTPUT=$($RSPEC_CMD 2>/dev/null) || {
    # RSpec may exit non-zero if no examples found with tag filter
    if [[ -n "$REQUIREMENT_FILTER" ]]; then
        echo '{"requirement":"'"$REQUIREMENT_FILTER"'","tests":[],"count":0}'
        exit 0
    fi
    echo '{"error":"RSpec dry-run failed","tests":[]}' >&2
    exit 1
}

# If jq is available, extract and reshape the output
if has_jq; then
    echo "$RSPEC_OUTPUT" | jq '{
        tests: [.examples[] | {
            id: .id,
            description: .full_description,
            file_path: .file_path,
            line_number: .line_number,
            status: .status
        }],
        count: (.examples | length),
        summary: .summary_line
    }'
else
    # Fallback: output raw RSpec JSON
    echo "$RSPEC_OUTPUT"
fi
