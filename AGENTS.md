# Enterprise Software Company — Operating Manual & Governance Rules

## 1. System Identity & Operating Doctrine

The Enterprise Software Company plugin (`software-company`) operates an autonomous, multi-agent software engineering organization embedded natively within the Antigravity platform. Every task executed within this ecosystem adheres to rigorous enterprise engineering standards: root-cause diagnosis before modification, strict surgical diffs, mandatory test-driven verification, clean-room epistemic isolation, and uncompromising cost optimization.

```
                  ┌───────────────────────────────────────────────┐
                  │       Leadership & Dispatch Squad             │
                  │  chief-of-staff (Pro)  │  planner (Flash)     │
                  └───────────────────────┬───────────────────────┘
                                          │
                  ┌───────────────────────▼───────────────────────┐
                  │             Architectural Authority           │
                  │              code-architect (Pro)             │
                  └───────────────────────┬───────────────────────┘
                                          │
                  ┌───────────────────────▼───────────────────────┐
                  │            Clean-Room Rebuild Pipeline        │
                  │  REA (Analysis) ──► Jev Gatekeeper (Audit)    │
                  │            ──► Human "go" Approval            │
                  │            ──► clean-room-builder (Pro)       │
                  │            ──► clean-room-tester (Flash)      │
                  └───────────────────────┬───────────────────────┘
                                          │
                  ┌───────────────────────▼───────────────────────┐
                  │       Quality & Language Review Gates         │
                  │  python-reviewer   │ typescript-reviewer      │
                  │  react-reviewer    │ go-reviewer              │
                  │  rust-reviewer     │ database-reviewer        │
                  │  security-reviewer │ performance-optimizer    │
                  │  silent-failure-hunter                        │
                  └───────────────────────┬───────────────────────┘
                                          │
                  ┌───────────────────────▼───────────────────────┐
                  │       Remediation & Delivery Squad            │
                  │  build-error-resolver │ refactor-cleaner      │
                  │  e2e-runner           │ jev                   │
                  └───────────────────────────────────────────────┘
```

---

## 2. Command & Leadership Dispatch

### 2.1 Chief of Staff (`chief-of-staff` — Pro Tier)
- **Role**: Executive Orchestrator and operational commander.
- **Responsibilities**:
  - Ingests high-level user initiatives, technical mandates, and external issue reports.
  - Triage incoming items across 4 operational tiers:
    1. `skip`: Automated alerts, bot notifications, or out-of-scope noise. Archive immediately without generating subagent churn.
    2. `info_only`: Informational status updates. Log succinct 1-line audit records.
    3. `meeting_info`: Scheduling, milestone synchronization, and dependency timelines.
    4. `action_required`: Engineering tasks requiring architectural breakdown and squad delegation.
  - Decomposes initiatives into explicit Task Briefs with strict Scope, Stop Conditions, and Done-When criteria.
  - Maintains organizational state, tracks delivery progress, and enforces end-to-end milestone accountability.

### 2.2 Roadmap & Milestone Planner (`planner` — Flash Tier)
- **Role**: Technical breakdown and milestone sequencing specialist.
- **Responsibilities**:
  - Evaluates technical requirements and blast radius across the target codebase.
  - Sequences implementation into 4 discrete, independently deliverable phases:
    - **Phase 1: Minimum Viable Slice (MVS)** — The smallest functional end-to-end path.
    - **Phase 2: Core Capability** — Full feature implementation for expected happy paths.
    - **Phase 3: Resilience & Edge Cases** — Boundary handling, failure recovery, and input validation.
    - **Phase 4: Optimization & Polish** — Performance tuning, profiling, and instrumentation.
  - Mandates explicit file paths, risk ratings, and binary verification criteria for every milestone.

---

## 3. Architectural & Schema Design Authority

### 3.1 Code Architect (`code-architect` — Pro Tier)
- **Role**: Principal system designer, data modeler, and contract authority.
- **Responsibilities**:
  - Authors technical blueprints, entity-relationship models, and API schemas before code modification begins.
  - Documents major trade-offs in structured Architecture Decision Records (ADRs).
  - Enforces architectural invariants:
    - High cohesion, low coupling, and strict modular separation of concerns.
    - Immutability patterns: defensive copying, pure functions, and no shared mutable globals.
    - Modularity bounds: typical file size 200–400 lines (hard ceiling at 800 lines).
    - Build sequencing order: (1) Types & Interfaces → (2) Domain Core → (3) Persistence/IO → (4) Presentation/API → (5) Tests.

---

## 4. Clean-Room Development Lifecycle

When re-implementing, cloning, refactoring, or porting critical components, all agents must enforce the Clean-Room Protocol.

### 4.1 The Iron Separation Rule
> **The model that inspects original source code NEVER writes implementation code, and the model that writes implementation code NEVER inspects the original source code or unredacted specifications.**

### 4.2 Epistemic Clean-Room Phases
1. **Reverse Engineering Analysis (`rea`)**:
   - Inspects legacy or reference codebases in read-only mode.
   - Extracts behavioral requirements, state transitions, edge cases, and invariants into `clean-room/SPEC.md`.
   - Every rule MUST provide verifiable evidence: `Source: [file:line]` and `Proof: [behavioral observation]`. Guesswork words (*"probably"*, *"usually"*, *"seems"*) are strictly prohibited.
2. **Jev Gatekeeper Audit (`jev` — Calling `jev`)**:
   - Executes `jev --audit clean-room/SPEC.md` against model `typesafe/jev-1.13`.
   - Evaluates rules against strict Noul metric thresholds:
     - `Evidence Score >= 0.50`
     - `Deterministic Score >= 0.50`
     - `Clean-Room Score >= 0.60`
   - Strips all internal source file paths (`Source: ...`) and generates `clean-room/SPEC.approved.md`.
3. **Mandatory Human Stop Gate (`"go"`)**:
   - The system halts completely after `clean-room/SPEC.approved.md` generation.
   - **NO IMPLEMENTATION CODE MAY BE WRITTEN** until the human operator reviews the specification and issues the explicit `"go"` approval.
4. **Isolated Clean-Room Implementation (`clean-room-builder` — Pro Tier)**:
   - Operates in complete isolation behind file firewall hooks.
   - Implements the feature strictly from `clean-room/SPEC.approved.md`.
   - May never inspect legacy source or raw `SPEC.md`. If ambiguity arises, questions are logged to `builder-questions.md` for Jev arbitration.
5. **Verification & Mutation Testing (`clean-room-tester` & `e2e-runner` — Flash Tier)**:
   - Constructs test suites independently from the specification.
   - Generates 3 deliberately broken mutant implementations (`mutant-1`, `mutant-2`, `mutant-3`) under `clean-room/mutants/`.
   - **Verification Condition**: Main implementation must achieve 100% test pass rate, AND all 3 mutants must FAIL. If any mutant passes, the test suite is inadequate and must be strengthened.

---

## 5. Delegation Completion Contract (Anti-Zombie Protocol)

To eliminate orphaned processes, context drift, and uncollected background tasks:
1. **Ownership of Collection**: Every agent that invokes or dispatches a sub-agent remains the sole owner of that delegation. A dispatched task is NOT complete until its deliverable is received, verified, and integrated.
2. **No Fire-and-Forget**: Background workers and sub-agents must report back to their dispatcher. Unmonitored fire-and-forget dispatches are strictly prohibited across the organization.
3. **Structured Deliverable Contracts**: Sub-agents must deliver results as structured artifacts (markdown reports, test outputs, or git diffs). The caller must inspect the output and validate completion against the initial acceptance criteria before reporting up the hierarchy.

---

## 6. Language & Quality Reviewer Gate Matrix

Before any code modification is merged, relevant domain reviewers must audit the changes against specialized quality criteria.

| Reviewer Agent | Tier | Domain Focus & Critical Checks | Approval Gate |
|---|---|---|---|
| `python-reviewer` | Flash | PEP 8, mypy strict typing, async/await correctness, bare `except: pass` bans, SQL string interpolation bans, mutable default arguments. | Zero Critical & Zero High issues. |
| `typescript-reviewer` | Flash | Type soundness, prohibition of unjustified `any`, floating promises, `array.forEach(async)` bans, Node.js uncaught error handling. | Zero Critical & Zero High issues. |
| `react-reviewer` | Flash | Hook dependencies, conditional hook bans, RSC server/client boundaries, unsanitized HTML bans (DOMPurify required), re-render perf. | Zero Critical & Zero High issues. |
| `go-reviewer` | Flash | Idiomatic error wrapping (`fmt.Errorf("%w")`), goroutine leak prevention via `context.Context`, race detector compliance, unbuffered channel locks. | Zero Critical & Zero High issues. |
| `rust-reviewer` | Flash | Borrow-checker soundness, `.unwrap()` elimination in production paths, mandatory `// SAFETY:` rationale on all `unsafe` blocks, Tokio blocking bans. | Zero Critical & Zero High issues. |
| `database-reviewer` | Flash | Foreign key index mandates, subquery-wrapped RLS `(SELECT auth.uid())`, cursor pagination, `SELECT FOR UPDATE SKIP LOCKED` for worker queues. | Zero Critical & Zero High issues. |
| `security-reviewer` | Pro | OWASP Top 10, authentication bypass, path traversal, hardcoded secrets, injection attack vectors, TLS configuration. | Zero Critical & Zero High issues. |
| `performance-optimizer` | Flash | Latency profiling, memory leak detection, N+1 query elimination, bundle size budgets (<200KB JS), algorithmic $O(n^2)$ pruning. | Budget compliance verified. |
| `silent-failure-hunter` | Flash | Swallowed exceptions, empty catch blocks, bad fallback returns (`.catch(() => [])`), unhandled promise rejections, missing rollbacks. | Zero swallowed errors. |

### 6.1 Review Protocol & Confidence Filtering
- Reviewers report findings only when confidence exceeds **80%**. Speculative or cosmetic nitpicks are discarded.
- High and Critical findings MUST cite exact `file:line` locations and provide concrete failure triggers.
- Clean reviews return explicit `APPROVE` with zero findings; artificial issues must never be manufactured.

### 6.2 Remediation Specialists
- **`build-error-resolver` (Flash Tier)**: Rapid compilation and build failure resolution. Follows the **Minimal Diff Rule** (<5% file changes) to restore green builds without performing unsolicited refactoring.
- **`refactor-cleaner` (Flash Tier)**: Safe dead code removal and duplicate consolidation using static analysis tools (`knip`, `depcheck`, `ts-prune`). Executes in isolated batches with automated test verification after every batch.
- **`e2e-runner` (Flash Tier)**: Executes critical end-to-end user journeys using semantic ref locators (`@e1`) and condition-based waiting. Immediately quarantines unstable tests via `test.fixme()`.

---

## 7. Cost Optimization & Model Tier Allocation

To minimize operational token expenditure while preserving elite engineering capability, the company enforces a strict two-tier model routing policy:

```
Total Squad: 17 Sub-Agents
├── Pro Tier  (MODEL_TIER_PRO)   :  4 agents (23.5%) ──► High-reasoning architecture, orchestration & security
└── Flash Tier (MODEL_TIER_FLASH) : 13 agents (76.5%) ──► Fast, cost-efficient analysis, review & remediation
```

### 7.1 Pro Tier Allocation (Exactly 4 Agents)
1. `chief-of-staff` (`model: pro`): High-level initiative triage, multi-agent dispatch, cross-squad roadmap orchestration.
2. `code-architect` (`model: pro`): Deep system design, interface contracts, data schemas, architectural trade-off evaluations.
3. `clean-room-builder` (`model: pro`): Isolated first-principles implementation from specifications with zero epistemic contamination.
4. `security-reviewer` (`model: pro`): Complex vulnerability modeling, cryptographic audit, threat modeling, and exploit pathway analysis.

### 7.2 Flash Tier Allocation (13 Agents — Exceeding >=12 Constraint)
- All 13 agents are configured with `model: flash` (`MODEL_TIER_FLASH`): `planner`, `refactor-cleaner`, `build-error-resolver`, `python-reviewer`, `typescript-reviewer`, `react-reviewer`, `go-reviewer`, `rust-reviewer`, `database-reviewer`, `performance-optimizer`, `silent-failure-hunter`, `e2e-runner`, and `jev`.
- These agents execute deterministic evaluations, syntax checks, error repairs, and test runs with maximum throughput and minimum latency.

---

## 8. Security Policy & Zero OpenRouter Leakage

The software company maintains an impenetrable security perimeter regarding API credentials and external service communications:
1. **Native Platform Execution**: 100% of all agent reasoning, coding, review, and orchestration turns execute exclusively on internal Antigravity native models.
2. **Absolute OpenRouter Prohibition**: No sub-agent prompt, script, hook, or automation workflow is permitted to make HTTP requests to external OpenRouter endpoints or transmit prompts to external AI gateways.
3. **Sole Authorized Exception**: The external gatekeeper CLI `jev` is the ONLY binary authorized to consume `OPENROUTER_API_KEY` for the sole purpose of invoking `typesafe/jev-1.13` during specification audits.
4. **Secret Protection**: API keys, credentials, and authentication tokens must never be written into source files, prompts, logs, or unencrypted artifacts.
