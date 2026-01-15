#!/bin/bash
#
# SubagentStop: Enforce bead lifecycle - supervisors must mark inreview
#

INPUT=$(cat)
AGENT_TRANSCRIPT=$(echo "$INPUT" | jq -r '.agent_transcript_path // empty')

[[ -z "$AGENT_TRANSCRIPT" || ! -f "$AGENT_TRANSCRIPT" ]] && echo '{"decision":"approve"}' && exit 0

# Extract last response
LAST_RESPONSE=$(tail -50 "$AGENT_TRANSCRIPT" | grep -o '"text":"[^"]*"' | tail -1 | sed 's/"text":"//;s/"$//')

# Check for supervisor agents (they must report BEAD_ID and inreview status)
AGENT_TYPE=$(echo "$INPUT" | jq -r '.subagent_type // empty')

if [[ "$AGENT_TYPE" =~ supervisor ]]; then
  # Worker supervisor is exempt from bead requirements (handles small tasks without beads)
  # But still subject to verbosity limits
  IS_WORKER="false"
  if [[ "$AGENT_TYPE" == *"worker"* ]]; then
    IS_WORKER="true"
  fi

  if [[ "$IS_WORKER" == "false" ]]; then
    # Supervisors must include completion report per beads-workflow-injection.md format:
    # BEAD {BEAD_ID} COMPLETE
    # Branch: bd-{BEAD_ID}
    # ...
    HAS_BEAD_COMPLETE=$(echo "$LAST_RESPONSE" | grep -cE "BEAD.*COMPLETE" 2>/dev/null || true)
    HAS_BRANCH=$(echo "$LAST_RESPONSE" | grep -cE "Branch:.*bd-" 2>/dev/null || true)

    # Supervisors must leave at least 1 comment on the bead
    # Note: grep -c exits 1 when no matches but still outputs "0", so use || true
    HAS_COMMENT=$(grep -c '"bd comment\|"command":"bd comment' "$AGENT_TRANSCRIPT" 2>/dev/null) || HAS_COMMENT=0

    # Supervisors must get code review approval before completing
    # Check for: 1) code-reviewer invocation AND 2) APPROVED comment
    HAS_CODE_REVIEW=$(grep -c 'code-reviewer\|"agent":"code-reviewer"' "$AGENT_TRANSCRIPT" 2>/dev/null) || HAS_CODE_REVIEW=0
    HAS_APPROVED=$(grep -c 'APPROVED\|"APPROVED"' "$AGENT_TRANSCRIPT" 2>/dev/null) || HAS_APPROVED=0

    # Default to 0 if empty
    [[ -z "$HAS_BEAD_COMPLETE" ]] && HAS_BEAD_COMPLETE=0
    [[ -z "$HAS_BRANCH" ]] && HAS_BRANCH=0
    [[ -z "$HAS_COMMENT" ]] && HAS_COMMENT=0
    [[ -z "$HAS_CODE_REVIEW" ]] && HAS_CODE_REVIEW=0
    [[ -z "$HAS_APPROVED" ]] && HAS_APPROVED=0

    # Check for code review approval (must have both invocation and approval)
    if [[ "$HAS_CODE_REVIEW" -lt 1 ]] || [[ "$HAS_APPROVED" -lt 1 ]]; then
      cat << 'EOF'
{"decision":"block","reason":"Code review required before completion.\n\n1. Request review:\n   mcp__provider_delegator__invoke_agent(\n     agent=\"code-reviewer\",\n     task_prompt=\"Review BEAD_ID: {ID}\\nBranch: bd-{ID}\"\n   )\n\n2. If approved, add comment:\n   bd comment {ID} \"CODE REVIEW: APPROVED - [summary]\"\n\n3. If not approved, fix issues and repeat."}
EOF
      exit 0
    fi

    # Check for at least 1 comment (satisfied by APPROVED comment)
    if [[ "$HAS_COMMENT" -lt 1 ]]; then
      cat << 'EOF'
{"decision":"block","reason":"Supervisor must leave at least 1 comment on the bead.\n\nRun: bd comment {BEAD_ID} \"Completed: [brief summary of work done]\"\n\nComments provide context for code review and future reference."}
EOF
      exit 0
    fi

    if [[ "$HAS_BEAD_COMPLETE" -lt 1 ]] || [[ "$HAS_BRANCH" -lt 1 ]]; then
      cat << 'EOF'
{"decision":"block","reason":"Supervisor must use completion report format:\n\nBEAD {BEAD_ID} COMPLETE\nBranch: bd-{BEAD_ID}\nFiles: [list]\nTests: pass\nSummary: [1 sentence]\n\nRun bd update {BEAD_ID} --status inreview first."}
EOF
      exit 0
    fi
  fi

  # Enforce concise responses for ALL supervisors (including worker)
  # Note: JSON escapes \n as literal chars, use printf to interpret
  DECODED_RESPONSE=$(printf '%b' "$LAST_RESPONSE")
  LINE_COUNT=$(echo "$DECODED_RESPONSE" | wc -l | tr -d ' ')
  CHAR_COUNT=${#DECODED_RESPONSE}

  if [[ "$LINE_COUNT" -gt 15 ]] || [[ "$CHAR_COUNT" -gt 800 ]]; then
    cat << EOF
{"decision":"block","reason":"Response too verbose (${LINE_COUNT} lines, ${CHAR_COUNT} chars). Max: 15 lines, 800 chars.\n\nUse concise format:\nBEAD {ID} COMPLETE\nBranch: bd-{ID}\nFiles: [names only]\nTests: pass\nSummary: [1 sentence]"}
EOF
    exit 0
  fi
fi

echo '{"decision":"approve"}'
