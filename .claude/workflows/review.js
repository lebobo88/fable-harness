export const meta = {
  name: 'review',
  description: 'Governance-forum review pipeline (taxonomy_blueprint.md Section 8.2) - runs one of the 10 standing review forums as a focused multi-agent pass over an existing artifact/change, without the full generate-from-scratch lifecycle that run.js drives.',
  phases: [
    { title: 'Review' },
    { title: 'Verify' },
  ],
}

// Same orchestration primitive as run.js - see its header comment for why this is a
// .claude/workflows/*.js script and not a fictional "teams/*.yaml" file. Reviewers are always
// TYPED agents (CONSTITUTION N7); this script has no filesystem access, so it relies on each
// agent's own file reads/writes for the actual artifact content and only orchestrates via
// schema-validated returns.

const FORUM_AGENTS = {
  discovery: ['discovery-researcher', 'strategy-author'],
  scope: ['spec-author'],
  design: ['designer', 'design-system-curator'],
  architecture: ['architect'],
  api_contract: ['api-designer'],
  threat_privacy: ['security-reviewer'],
  test_readiness: ['test-strategist'],
  release_readiness: ['release-planner'],
  incident_postmortem: ['ops-author'],
  service_review: ['ops-author', 'governance-author'],
}

const VERDICT_SCHEMA = {
  type: 'object',
  properties: {
    verdict: { type: 'string', enum: ['pass', 'pass-with-notes', 'reject'] },
    notes: { type: 'string' },
  },
  required: ['verdict'],
}

// Defensive normalization + guard (same rationale as run.js - see its comment: args can
// arrive as a JSON-encoded string rather than an object in this environment).
let resolvedArgs = args
if (typeof resolvedArgs === 'string') {
  try {
    resolvedArgs = JSON.parse(resolvedArgs)
  } catch (e) {
    throw new Error(`review.js received args as a string that isn't valid JSON either: ${resolvedArgs}`)
  }
}
if (!resolvedArgs || typeof resolvedArgs !== 'object' || !resolvedArgs.forum || !resolvedArgs.run_id || !resolvedArgs.subject) {
  throw new Error(
    `review.js received malformed args (expected {forum, run_id, subject}). Received (after normalization attempt): ${JSON.stringify(resolvedArgs)}. Original raw args: ${JSON.stringify(args)}.`
  )
}

const forum = resolvedArgs.forum
const runId = resolvedArgs.run_id
const subject = resolvedArgs.subject // what's being reviewed: a spec path, a PR description, etc.

const reviewers = FORUM_AGENTS[forum]
if (!reviewers) {
  throw new Error(
    `Unknown governance forum '${forum}'. Valid forums (taxonomy_blueprint.md Section 8.2): ${Object.keys(FORUM_AGENTS).join(', ')}`
  )
}

phase('Review')
log(`Running the '${forum}' governance forum (reviewers: ${reviewers.join(', ')}) for run_id=${runId}.`)

async function runReviewer(reviewerType) {
  const reviewResult = await agent(
    `Perform a ${forum} governance-forum review pass over: ${subject}. run_id=${runId}. Write your review notes to .fable/${runId}/artifacts/ per artifact-conventions. This is a REVIEW pass over EXISTING work, not new production - if you propose changes, follow CONSTITUTION N9 (Preserved Invariants vs Changed Behaviors) explicitly.`,
    { agentType: reviewerType, phase: 'Review', label: `review:${reviewerType}` }
  )

  const verdict = await agent(
    `Independently verify the '${forum}' review pass performed by ${reviewerType} for run_id=${runId}. Reviewer summary: ${reviewResult}`,
    { agentType: 'verifier', phase: 'Verify', label: `verify:${reviewerType}`, schema: VERDICT_SCHEMA }
  )

  return { reviewer: reviewerType, verdict: verdict.verdict, notes: verdict.notes }
}

const results = await pipeline(reviewers, (reviewerType) => runReviewer(reviewerType))

const anyReject = results.some((r) => r && r.verdict === 'reject')

if (anyReject) {
  log(`Forum '${forum}' has at least one reject verdict - governance forum exit criteria (taxonomy_blueprint.md Section 8.2) NOT met.`)
}

return { forum, runId, results, exitCriteriaMet: !anyReject }
