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

// Canonical stage-state schema init instruction (single source of truth: reflexion-coach.md,
// verify-gate/SKILL.md, stop-verify-gate.ps1). run.js itself has NO filesystem access, so the
// stages/<stage>.json file is initialized by the (typed, Write-capable) producer at generate
// time via this instruction. Keep the JSON byte-identical to every other reader/writer of it -
// the Stop hook keys turn-gating off `last_verdict`, so a stage that never wrote this file was
// invisible to verification and produced the false-negative reject this fix closes.
function stageStateInitInstruction(stage) {
  return (
    `Stage-state bookkeeping - do this FIRST, before your main work: if the file ` +
    `.fable/${runId}/stages/${stage}.json does NOT already exist, create it with EXACTLY this ` +
    `content and no extra or renamed fields: ` +
    `{"stage": "${stage}", "verify_loops": 0, "reflexion_used": false, "last_verdict": null, "history": []} ` +
    `- if it already exists, leave it exactly as-is. This is the canonical stage-state schema ` +
    `shared verbatim with reflexion-coach, verify-gate and the Stop hook; it must stay byte-identical.`
  )
}

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
      `Run the Codex Rubber-Duck Bridge (.claude/hooks/lib/codex-review.ps1) for stage=${stage}, run_id=${runId}. Producer summary: ${producerSummary}. In addition to your usual .fable/${runId}/verdicts/${stage}-codex.json write, ALSO mirror your normalized verdict to the uniform per-stage file .fable/${runId}/verdicts/${stage}.json in the shape {"verdict": "pass|pass-with-notes|reject", "issues": ["..."], "source": "codex"} so reflexion-coach and the terminal stage-state recorder find one canonical verdict path for every judged stage.`,
      { agentType: 'judge-cross-vendor', phase: 'Judge', label: `judge:${stage}`, schema: VERDICT_SCHEMA }
    )
  }
  return agent(
    `Judge the ${stage} artifact for run_id=${runId} at the next model tier up (Haiku output -> Sonnet judge; Sonnet -> Opus). Producer summary: ${producerSummary}. Emit exactly one of pass/pass-with-notes/reject per CONSTITUTION N4, and PERSIST that verdict to .fable/${runId}/verdicts/${stage}.json in the shape {"verdict": "pass|pass-with-notes|reject", "issues": ["..."], "source": "same-tier"} before returning. reflexion-coach and the stage-state recorder read this file, so it MUST exist on disk for every judged stage - on pass exactly as much as on reject.`,
    { phase: 'Judge', label: `judge:${stage}`, schema: VERDICT_SCHEMA }
  )
}

async function runStage(section) {
  const producerType = SECTION_AGENT[section] || 'docs-author'
  const stage = `${section}-${producerType}`
  const isCodeStage = section === '4.8' // engineer: real committed code, not a .md artifact

  // ---- Generate. The producer dispatch ALSO initializes .fable/<run_id>/stages/<stage>.json
  // (agent-mediated, since run.js has no filesystem access) so EVERY stage - passing or not -
  // has its stage-state file from the start, not only on the reject path via reflexion-coach.
  // For code-building stages (4.8 engineer) the real output is committed code, so we additionally
  // require a short summary artifact so verification/missability have on-disk evidence to point at.
  let producePrompt =
    `Produce the ${section} artifact for run_id=${runId}, stage=${stage}. Request: ${request}. ` +
    `Write to .fable/${runId}/artifacts/ per artifact-conventions. ` +
    stageStateInitInstruction(stage)
  if (isCodeStage) {
    producePrompt +=
      ` This is a CODE-BUILDING stage: after you commit your implementation, ALSO write a short ` +
      `summary artifact to .fable/${runId}/artifacts/${stage}-summary.md recording the commit SHA, ` +
      `the exact list of files changed, and the exact build/test commands (naming the runner, e.g. ` +
      `vite/vitest/pytest/npm) needed to reproduce a green build. This summary is the on-disk ` +
      `evidence the verifier and missability-inspector use to confirm code work that lives in the ` +
      `project tree rather than as a descriptive .md artifact - do not skip it even on a clean build.`
  }

  let producerResult = await agent(producePrompt, {
    agentType: producerType,
    phase: 'Generate',
    label: `generate:${stage}`,
  })

  let verdict = await judgeStage(stage, section, producerResult)

  // ---- Reflexion x1: on reject, dispatch reflexion-coach (the Write-capable stage-state steward
  // - it updates .fable/<run_id>/stages/<stage>.json, since the read-only `verifier` agent
  // deliberately never writes it). At most one retry, ever, per stage.
  if (verdict.verdict === 'reject') {
    const coach = await agent(
      `Stage ${stage} (run_id=${runId}, section=${section}) received a reject verdict. Read .fable/${runId}/stages/${stage}.json (initialized by the producer at generate time; create it per your canonical schema only if it is somehow absent) and the rejecting verdict at .fable/${runId}/verdicts/${stage}.json (or ${stage}-codex.json). Apply the Reflexion x1 + 3-loop policy, and either compose a retry prompt or escalate. Rejecting verdict: ${JSON.stringify(verdict)}. Original producer dispatch: Produce the ${section} artifact for run_id=${runId}, stage=${stage}. Request: ${request}.`,
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

  // ---- Verify (independent, read-only). The verifier re-derives from disk and NEVER writes the
  // stage-state file (its entire value is that it cannot alter what it inspects). For code stages
  // it must re-derive from git + build + tests, not only from a .md artifact under artifacts/.
  const verifyResult = await agent(
    `Run verify-gate for stage=${stage}, run_id=${runId}. Latest judge verdict: ${verdict.verdict}. ` +
      `The stage-state file .fable/${runId}/stages/${stage}.json was initialized by the producer at ` +
      `generate time and updated by any Reflexion retry - read it, do not assume it is missing. Read ` +
      `the persisted judge verdict at .fable/${runId}/verdicts/${stage}.json (or ${stage}-codex.json). ` +
      (isCodeStage
        ? `This is a CODE-BUILDING stage: its real output is committed code in the project tree plus ` +
          `.fable/${runId}/artifacts/${stage}-summary.md, NOT a descriptive .md artifact. Re-derive its ` +
          `claims from git log / git show for the commit SHA in that summary and by running the summary's ` +
          `build/test commands in read-only/report mode (the project's vite build, vitest, pytest) - do ` +
          `NOT reject merely because there is no prose .md artifact for this section. `
        : ``) +
      `Enforce Reflexion x1 and the 3-loop escalation ceiling per CONSTITUTION N3. You are READ-ONLY: ` +
      `do not write the stage-state file yourself.`,
    { agentType: 'verifier', phase: 'Verify', label: `verify:${stage}`, schema: VERDICT_SCHEMA }
  )

  // ---- Terminal stage-state write. Because `verifier` is read-only, the authoritative verify
  // verdict is stamped into stages/<stage>.json by a separate, explicitly-dispatched Write-capable
  // step: reflexion-coach in RECORD-ONLY mode (the stage-state steward that owns this schema). This
  // is what makes /run's self-report truthful: without it a passing stage left last_verdict=null
  // (or no file at all), so the Stop hook, missability and finalize all saw an unverified stage and
  // fail-closed to a spurious reject/"surfaced". Record-only: it does NOT compose a retry and does
  // NOT touch reflexion_used - it only records the terminal verify outcome.
  await agent(
    `RECORD-ONLY stage-state update for stage=${stage}, run_id=${runId}. Do NOT compose a retry, do ` +
      `NOT change reflexion_used, and do NOT apply the reject-retry decision logic - this is a pure ` +
      `terminal record. Read .fable/${runId}/stages/${stage}.json (canonical schema) and update it to ` +
      `reflect the just-completed independent verification: set "last_verdict" to "${verifyResult.verdict}", ` +
      `increment "verify_loops" by 1 for this verify attempt, and append ` +
      `{"verdict": "${verifyResult.verdict}", "notes": "verifier terminal verdict", "phase": "verify"} to ` +
      `"history". Preserve every other existing field and all prior history entries unchanged (N9). Return ` +
      `the updated last_verdict and verify_loops so the caller can confirm the on-disk state matches.`,
    { agentType: 'reflexion-coach', phase: 'Verify', label: `record:${stage}` }
  )

  return { section, stage, agentType: producerType, verdict: verifyResult.verdict }
}

const sectionsToRun = taxonomy.sections.filter((s) => true) // every mapped section runs; unmapped kinds fall back to docs-author inside runStage
if (sectionsToRun.length === 0) {
  log('No mapped sections (unexpected) - falling back to the 4.13 docs floor.')
  sectionsToRun.push('4.13')
}

// ---- Section scheduling: two dependency waves, NOT one flat concurrent pipeline.
//
// Most sections are genuinely independent and pipeline concurrently. But some sections'
// artifacts DESCRIBE other sections' output rather than standing alone - §4.13
// (docs/changelog/release notes) documents what §4.8 (engineer) actually built. Running
// those concurrently means the docs producer writes a changelog for code that does not
// exist on disk yet, and its judge then correctly rejects it for describing unearned work.
//
// That is a scheduling defect, not a judging defect: the judge is right every time. It was
// observed as a false-negative "surfaced" run twice in a row (runs 20260726-213456 and
// 20260726-221514, both SOLAR FRONTIER Phase 1) and is the same failure class already
// recorded in memory/invariants.md for run 20260711-141439-p1-design-system.
//
// The barrier between waves is deliberate and is the justified case for one: wave 2 needs
// EVERY wave-1 stage's files actually on disk before it can describe them truthfully.
const DESCRIBES_OTHER_SECTIONS = new Set(['4.13'])

const producingSections = sectionsToRun.filter((s) => !DESCRIBES_OTHER_SECTIONS.has(s))
const describingSections = sectionsToRun.filter((s) => DESCRIBES_OTHER_SECTIONS.has(s))

// When 4.13 is the ONLY mapped section (the trivial-scope taxonomy floor) it has nothing to
// wait for and must run in wave 1, or the run would produce no stages at all.
const wave1 = producingSections.length > 0 ? producingSections : describingSections
const wave2 = producingSections.length > 0 ? describingSections : []

const wave1Results = await pipeline(wave1, (section) => runStage(section))

let wave2Results = []
if (wave2.length > 0) {
  log(
    `Wave 1 complete (${wave1.join(', ')}). Running dependent section(s) ${wave2.join(', ')} ` +
      `now that the code and artifacts they document are on disk.`
  )
  wave2Results = await pipeline(wave2, (section) => runStage(section))
}

const stageResults = [...wave1Results, ...wave2Results]

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
  `Run the 21-item missability checklist against run_id=${runId}'s archived artifacts before finalize. ` +
    `The run directory is .fable/${runId}/ resolved from the FABLE-HARNESS project root (CLAUDE_PROJECT_DIR / repo root), ` +
    `NOT from any transient cwd. Both .fable/${runId}/taxonomy_map.json and the .fable/${runId}/artifacts/ directory DO ` +
    `exist for this run: FIRST Glob .fable/${runId}/artifacts/* to enumerate the actual artifact files and read ` +
    `.fable/${runId}/taxonomy_map.json's mapped sections, THEN score - never report either as absent without having ` +
    `actually listed the directory (a "no artifacts/ directory exists" claim when files are present is itself a defect ` +
    `per N4). Note that code-building sections (e.g. 4.8 engineer) are represented on disk by a <section>-<agent>-summary.md ` +
    `plus committed code, not a full prose .md - treat that summary as valid coverage evidence for that section. Always ` +
    `write .fable/${runId}/missability-report.json on both outcomes.`,
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

// ---- Finalize.
//
// master-plan-patcher is dispatched HERE, by the workflow, rather than from inside
// run-finalizer. This is not a style preference - it is a hard constraint:
// Workflow-dispatched subagents do not receive nested agent-spawning capability, so
// `run-finalizer` cannot dispatch another typed agent no matter what its frontmatter
// declares. Its `tools:` line lists `Task`, but that tool is simply absent at runtime.
//
// Before this fix the finalize path was STRUCTURALLY UNREACHABLE: run-finalizer would
// correctly refuse (per N7, it must never patch PROJECT_MASTER.md inline in place of the
// typed agent; per N4, it must not write status:finalized over a step it could not
// complete), so *every run in this harness's history* ended unfinalized - no
// summary.json anywhere, no .fable/runs.jsonl, no PROJECT_MASTER.md. The agent was
// behaving correctly; the orchestration was wrong.
//
// run.js DOES have agent(), so dispatching the typed master-plan-patcher from here
// satisfies N7 properly and leaves run-finalizer with only work it can actually do.
phase('Finalize')
await agent(
  `Patch (or create) PROJECT_MASTER.md for the calling project from run_id=${runId}'s archived artifacts, ` +
    `mapping this run's taxonomy sections (${taxonomy.sections.join(', ')}) onto PROJECT_MASTER.md's ` +
    `corresponding sections per taxonomy_blueprint.md Section 9. The run directory is .fable/${runId}/ ` +
    `resolved from the FABLE-HARNESS project root. This dispatch replaces the call run-finalizer used to ` +
    `make itself - run-finalizer no longer performs this step and will verify your output rather than repeat it.`,
  { agentType: 'master-plan-patcher', phase: 'Finalize', label: 'master-plan-patch' }
)

// run-finalizer independently re-derives run health from disk (N7 provenance) and may still
// refuse even if the checks above passed - ALWAYS trust its actual returned decision, never
// hardcode a 'finalized' status just because the dispatch itself completed without error.
const finalized = await agent(
  `Finalize run_id=${runId}: write the run summary, archive any best-of-N losers, and update .fable/runs.jsonl. ` +
    `NOTE: master-plan-patcher has ALREADY been dispatched by the workflow driver immediately before you ` +
    `(it cannot be dispatched from inside you - Workflow subagents have no nested agent-spawning tool, ` +
    `which is why this step moved). Do NOT attempt to dispatch it and do NOT treat its absence from your ` +
    `own toolset as a blocker. VERIFY its work landed by checking PROJECT_MASTER.md on disk, and refuse ` +
    `(finalized: false) if it did not. Return whether finalization actually succeeded (finalized: true) or ` +
    `was refused (finalized: false) per your own independent disk-based checks, and why.`,
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
