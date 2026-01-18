#!/bin/bash
#
# PreToolUse:Task - Enforce bead exists before supervisor dispatch
#
# Supervisors (except worker) must have BEAD_ID in prompt.
# This ensures all significant work is tracked.
#

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')

[[ "$TOOL_NAME" != "Task" ]] && exit 0

SUBAGENT_TYPE=$(echo "$INPUT" | jq -r '.tool_input.subagent_type // empty')
PROMPT=$(echo "$INPUT" | jq -r '.tool_input.prompt // empty')

# Only enforce for supervisors
[[ ! "$SUBAGENT_TYPE" =~ supervisor ]] && exit 0

# Worker-supervisor is exempt (handles small tasks without beads)
[[ "$SUBAGENT_TYPE" == *"worker"* ]] && exit 0

# Check for BEAD_ID in prompt
if [[ "$PROMPT" != *"BEAD_ID:"* ]]; then
  cat << 'EOF'
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"<bead-required>\n<priority>CREATE A BEAD FIRST - Do NOT dispatch worker-supervisor as a workaround.</priority>\n\n<rule>\nAll supervisor work MUST be tracked with a bead.\nWorker-supervisor is ONLY for trivial tasks (typos, single-line fixes, config tweaks).\nIf the task requires more than minimal code changes, CREATE A BEAD.\n</rule>\n\n<action>\n1. Create bead:\n   bd create \"Task title\" -d \"Detailed description for supervisor\"\n\n2. Then dispatch supervisor with:\n   BEAD_ID: {id}\n   Branch: bd-{id}\n   Task: [description]\n</action>\n\n<warning>\nDo NOT use worker-supervisor to avoid bead creation.\nBeads enable: code review, branch tracking, merge enforcement.\n</warning>\n</bead-required>"}}
EOF
  exit 0
fi

exit 0
