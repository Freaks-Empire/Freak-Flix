# Phase 3: Onboarding and Source Setup - Context

**Gathered:** 2026-03-01
**Status:** Ready for planning

<domain>
## Phase Boundary

This phase defines the first-run setup experience where users choose library types and connect sources (local, OneDrive, or remote profiles). It clarifies onboarding behavior and recovery paths within this scope and does not add new capabilities beyond setup and source connection.

</domain>

<decisions>
## Implementation Decisions

### Onboarding flow
- Use a linear guided onboarding wizard.
- Show progress using checklist-style completion states.
- If onboarding is interrupted, prompt users to resume where they left off or restart.
- Entering Home should not be hard-blocked by source connection completion.

### Source priorities
- Do not prioritize a default source type; users choose their first source path.
- Do not push source-connection count during first run; source setup remains optional in onboarding.
- Present SFTP, FTP, and WebDAV as separate remote protocol cards.
- After onboarding, browse/search defaults should include all enabled sources.

### Connection recovery
- Show connection/auth failures inline near relevant fields, with local context.
- Primary recovery path should be guided troubleshooting before retry.
- If OneDrive Device Code flow times out or is abandoned, return to source list and mark OneDrive incomplete.
- After repeated failures, show a short troubleshooting checklist and docs link.

### Library type setup
- Preselect no library types; users opt in explicitly.
- Present type choices as visual cards.
- Put Adult type in a separate explicit privacy section.
- Require a final review step summarizing selected types and sources before finishing onboarding.

### Claude's Discretion
- Exact visual styling and wording of step labels, checklist markers, and helper text.
- Exact copy of troubleshooting checklist and docs link labels.
- Exact wording for resume/restart and incomplete-source prompts.

</decisions>

<specifics>
## Specific Ideas

- Keep onboarding user-controlled: no preselected types and no source-type bias.
- Keep recovery practical: inline context plus guided troubleshooting for failed connections.
- Include a mandatory final review summary before onboarding completion.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 03-onboarding-and-source-setup*
*Context gathered: 2026-03-01*
