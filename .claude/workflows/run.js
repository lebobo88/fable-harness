export const meta = {
  name: 'run',
  description: 'FABLE-HARNESS lifecycle driver: setup -> generate per mapped taxonomy section -> judge -> verify (Reflexion x1, 3-loop escalate) -> missability -> finalize.',
  phases: [
    { title: 'Setup' },
    { title: 'Generate' },
    { title: 'Judge' },
    { title: 'Verify' },
    { title: 'Missability' },
    { title: 'Finalize' },
  ],
}

// This is the REAL orchestration primitive for FABLE-HARNESS (see AGENTS.md and plan.md) -
// replaces the fictional ".claude/teams/*.yaml" idea from an earlier draft. Team-config data
// under .claude/team-configs/*.yaml is plain YAML this script (or a future variant) can read
// via an agent, never a Claude Code primitive itself.
//
// Every dispatched agent is a TYPED producer/governance agent (CONSTITUTION N7) - never
// agentType-less generic dispatch. This script has no filesystem access (Workflow tool
// constraint), so branching decisions come from each agent's schema-validated return value;
// the authoritative state still lives in .fable/<run_id>/*.json, written by the agents
// themselves per their own file contracts.

const SECTION_AGENT = {
  '4.1': 'strategy-author',
  '4.2': 'discovery-researcher',
  '4.3': 'spec-author',
  '4.4': 'designer',
  '4.5': 'data-modeler',
  '4.6': 'architect',
  '4.7': 'api-designer',
  '4.8': 'engineer',
  '4.9': 'security-reviewer',
  '4.10': 'test-strategist',
  '4.11': 'release-planner',
  '4.12': 'ops-author',
  '4.13': 'docs-author',
  '4.15': 'ai-controls-author',
  '4.16': 'retirement-planner',
}

const TRIAGE_SCHEMA = {
  type: 'object',
  properties: {
    scope: { type: 'string', enum: ['trivial', 'standard', 'major'] },
    taxonomy_floor_only: { type: 'boolean' },
  },
  required: ['scope', 'taxonomy_floor_only'],
}

const TAXONOMY_SCHEMA = {
  type: 'object',
  properties: {
    sections: { type: 'array', items: { type: 'string' } },
    floor_applied: { type: 'boolean' },
  },
  required: ['sections'],
}

const ROUTE_SCHEMA = {
  type: 'object',
  properties: {
    stage: { type: 'string' },
    route: { type: 'string', enum: ['same-tier', 'cross-vendor'] },
    judge_agent: { type: 'string' },
    reason: { type: 'string' },
  },
  required: ['stage', 'route', 'judge_agent'],
}

const VERDICT_SCHEMA = {
  type: 'object',
  properties: {
    verdict: { type: 'string', enum: ['pass', 'pass-with-notes', 'reject'] },
    notes: { type: 'string' },
  },
  required: ['verdict'],
}

const REFLEXION_SCHEMA = {
  type: 'object',
  properties: {
    action: { type: 'string', enum: ['retry', 'escalate'] },
    retry_prompt: { type: ['string', 'null'] },
    generator_agent_type: { type: ['string', 'null'] },
  },
  required: ['action'],
}

const FINALIZE_SCHEMA = {
  type: 'object',
  properties: {
    finalized: { type: 'boolean' },
    reason: { type: 'string' },
  },
  required: ['finalized', 'reason'],
}

// Defensive normalization + guard: Phase 7 live validation caught `args` arriving as a
// JSON-ENCODED STRING rather than an object in this environment (even when the calling tool
// call passed a real object), which silently produced `undefined` for args.run_id/args.request
// and leaked the literal string "undefined" into every downstream dispatch prompt and
// .fable/<run_id>/ path. Every downstream agent correctly failed closed per N4 when that
// happened - this guard stops the bad state at the source instead.
let resolvedArgs = args
if (typeof resolvedArgs === 'string') {
  try {
    resolvedArgs = JSON.parse(resolvedArgs)
  } catch (e) {
    throw new Error(`run.js received args as a string that isn't valid JSON either: ${resolvedArgs}`)
  }
}
if (!resolvedArgs || typeof resolvedArgs !== 'object' || !resolvedArgs.run_id || !resolvedArgs.request) {
  throw new Error(
    `run.js received malformed args (expected {run_id, request}). Received (after string-to-object normalization attempt): ${JSON.stringify(resolvedArgs)}. Original raw args: ${JSON.stringify(args)}.`
  )
}

const runId = resolvedArgs.run_id
const request = resolvedArgs.request

phase('Setup')
log(`FABLE run ${runId}: triage -> profile -> taxonomy for: ${request}`)

const triage = await agent(
  `Classify this request per your contract. run_id=${runId}. Request: ${request}. Also return the schema fields in addition to your normal .fable/${runId}/run.json write.`,
  { agentType: 'triage', phase: 'Setup', label: 'triage', schema: TRIAGE_SCHEMA }
)

await agent(
  `Load the project profile for run_id=${runId}, given scope=${triage.scope}.`,
  { agentType: 'profile-loader', phase: 'Setup', label: 'profile-loader' }
)

const taxonomy = await agent(
  `Map this request to taxonomy sections. run_id=${runId}, scope=${triage.scope}, taxonomy_floor_only=${triage.taxonomy_floor_only}. Request: ${request}`,
  { agentType: 'taxonomy-mapper', phase: 'Setup', label: 'taxonomy-mapper', schema: TAXONOMY_SCHEMA }
)

log(`Mapped to sections: ${taxonomy.sections.join(', ')} (floor_applied=${taxonomy.floor_applied})`)

// ---- Generate + Judge + Verify per mapped section, pipelined (each section verifies as soon
// as its own generate+judge finishes - no barrier across sections, per the canonical pattern).
async function judgeStage(stage, section, producerSummary) {
  const route = await agent(
    `Decide judge routing for stage=${stage}, run_id=${runId}, scope=${triage.scope}, section=${section}.`,
    { agentType: 'judge-router', phase: 'Judge', label: `route:${stage}`, schema: ROUTE_SCHEMA }
  )

  if (route.route === 'cross-vendor') {
    return agent(
      `Run the Codex Rubber-Duck Bridge (.claude/hooks/lib/codex-review.ps1) for stage=${stage}, run_id=${runId}. Producer summary: ${producerSummary}`,
      { agentType: 'judge-cross-vendor', phase: 'Judge', label: `judge:${stage}`, schema: VERDICT_SCHEMA }
    )
  }
  return agent(
    `Judge the ${stage} artifact for run_id=${runId} at the next model tier up (Haiku output -> Sonnet judge; Sonnet -> Opus). Producer summary: ${producerSummary}. Emit exactly one of pass/pass-with-notes/reject per CONSTITUTION N4.`,
    { phase: 'Judge', label: `judge:${stage}`, schema: VERDICT_SCHEMA }
  )
}

async function runStage(section) {
  const producerType = SECTION_AGENT[section] || 'docs-author'
  const stage = `${section}-${producerType}`

  let producerResult = await agent(
    `Produce the ${section} artifact for run_id=${runId}, stage=${stage}. Request: ${request}. Write to .fable/${runId}/artifacts/ per artifact-conventions.`,
    { agentType: producerType, phase: 'Generate', label: `generate:${stage}` }
  )

  let verdict = await judgeStage(stage, section, producerResult)

  // ---- Reflexion x1: on reject, dispatch reflexion-coach (the one Write-capable step in
  // this loop - it creates/updates .fable/<run_id>/stages/<stage>.json, since the read-only
  // `verifier` agent deliberately never writes it). At most one retry, ever, per stage.
  if (verdict.verdict === 'reject') {
    const coach = await agent(
      `Stage ${stage} (run_id=${runId}, section=${section}) received a reject verdict. Read or create .fable/${runId}/stages/${stage}.json per your canonical schema, apply the Reflexion x1 + 3-loop policy, and either compose a retry prompt or escalate. Rejecting verdict: ${JSON.stringify(verdict)}. Original producer dispatch: Produce the ${section} artifact for run_id=${runId}, stage=${stage}. Request: ${request}.`,
      { agentType: 'reflexion-coach', phase: 'Verify', label: `reflexion:${stage}`, schema: REFLEXION_SCHEMA }
    )

    if (coach.action === 'retry' && coach.retry_prompt) {
      producerResult = await agent(coach.retry_prompt, {
        agentType: coach.generator_agent_type || producerType,
        phase: 'Generate',
        label: `retry:${stage}`,
      })
      verdict = await judgeStage(stage, section, producerResult)
    }
    // If coach.action === 'escalate', we deliberately do NOT retry again - the stage carries
    // its (still-rejected) verdict forward into verification, which will itself see the
    // stage-state file's exhausted Reflexion/loop budget and fail closed per N4, exactly as
    // designed - no separate escalation branching needed here.
  }

  const verifyResult = await agent(
    `Run verify-gate for stage=${stage}, run_id=${runId}. Latest verdict: ${verdict.verdict}. The stage-state file .fable/${runId}/stages/${stage}.json should already exist (created by reflexion-coach on the first reject, if any occurred) - read it, do not assume it is missing. Enforce Reflexion x1 and the 3-loop escalation ceiling per CONSTITUTION N3.`,
    { agentType: 'verifier', phase: 'Verify', label: `verify:${stage}`, schema: VERDICT_SCHEMA }
  )

  return { section, stage, agentType: producerType, verdict: verifyResult.verdict }
}

const sectionsToRun = taxonomy.sections.filter((s) => true) // every mapped section runs; unmapped kinds fall back to docs-author inside runStage
if (sectionsToRun.length === 0) {
  log('No mapped sections (unexpected) - falling back to the 4.13 docs floor.')
  sectionsToRun.push('4.13')
}

const stageResults = await pipeline(sectionsToRun, (section) => runStage(section))

// ---- Best-of-N for major scope on the engineering stage, via oracle-evaluator + worktrees.
if (triage.scope === 'major' && sectionsToRun.includes('4.8')) {
  phase('Generate')
  log('Major scope with an engineering stage - dispatching oracle-evaluator for best-of-N comparison across worktree candidates.')
  await agent(
    `Run best-of-N Borda-count comparison for run_id=${runId}'s engineering stage across its worktree-isolated candidates.`,
    { agentType: 'oracle-evaluator', phase: 'Generate', label: 'best-of-n' }
  )
}

// ---- Missability gate before finalize.
phase('Missability')
const missability = await agent(
  `Run the 20-item missability checklist against run_id=${runId}'s archived artifacts before finalize.`,
  { agentType: 'missability-inspector', phase: 'Missability', label: 'missability', schema: VERDICT_SCHEMA }
)

const unresolvedStages = stageResults.filter((r) => r && r.verdict === 'reject')

if (missability.verdict === 'reject') {
  log('Missability check failed - run downgraded to "surfaced" status; skipping finalize.')
  return { runId, status: 'surfaced', stageResults, missability }
}

if (unresolvedStages.length > 0) {
  log(`${unresolvedStages.length} stage(s) still show a reject verdict after Reflexion x1 (${unresolvedStages.map((s) => s.stage).join(', ')}) - surfacing rather than attempting finalize.`)
  return { runId, status: 'surfaced', taxonomy, stageResults, missability, unresolvedStages }
}

// ---- Finalize: patch PROJECT_MASTER.md, write run summary, archive best-of-N losers.
// run-finalizer independently re-derives run health from disk (N7 provenance) and may still
// refuse even if the checks above passed - ALWAYS trust its actual returned decision, never
// hardcode a 'finalized' status just because the dispatch itself completed without error.
phase('Finalize')
const finalized = await agent(
  `Finalize run_id=${runId}: write the run summary, call master-plan-patcher, archive any best-of-N losers, and update .fable/runs.jsonl. Return whether finalization actually succeeded (finalized: true) or was refused (finalized: false) per your own independent disk-based checks, and why.`,
  { agentType: 'run-finalizer', phase: 'Finalize', label: 'finalize', schema: FINALIZE_SCHEMA }
)

return {
  runId,
  status: finalized.finalized ? 'finalized' : 'surfaced',
  taxonomy,
  stageResults,
  missability,
  finalized,
}
