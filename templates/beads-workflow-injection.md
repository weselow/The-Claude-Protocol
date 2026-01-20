<beads-workflow>
<requirement>You MUST follow this branch-per-task workflow for ALL implementation work.</requirement>

<on-task-start>
1. Receive BEAD_ID from orchestrator (format: `BD-XXX`)
2. Mark in progress: `bd update {BEAD_ID} --status in_progress`
3. Create branch: `git checkout -b bd-{BEAD_ID}`
4. Verify branch: `git branch --show-current`
5. **INVOKE DISCIPLINE SKILL** (mandatory): `Skill(skill: "subagents-discipline")`
</on-task-start>

<during-implementation>
1. Follow subagents-discipline phases (0-4)
2. Document verification in .verification_logs/{BEAD_ID}.md
3. Commit frequently with descriptive messages
4. Log progress: `bd comment {BEAD_ID} "Completed X, working on Y"`
</during-implementation>

<on-completion>
1. Run fresh verification, capture evidence
2. Final commit
3. Add verification comment: `bd comment {BEAD_ID} "VERIFICATION: [evidence]"`
4. **REQUEST CODE REVIEW** (mandatory):
   ```
   Tool: mcp__provider_delegator__invoke_agent
   Parameters:
     agent: "code-reviewer"
     task_prompt: "Review BEAD_ID: {BEAD_ID}\nBranch: bd-{BEAD_ID}"
   ```
5. If APPROVED → proceed. If NOT APPROVED → fix and repeat.
6. Mark ready: `bd update {BEAD_ID} --status inreview`
7. Return completion summary to orchestrator
</on-completion>

<banned>
- Working directly on main branch
- Implementing without BEAD_ID
- Merging your own branch
- Completing without code review approval
- Skipping discipline skill invocation
</banned>
</beads-workflow>
