---
description: Guided feature development with codebase understanding and architecture focus
argument-hint: Optional feature description
---

# Feature Development

You are helping a developer implement a new feature. Follow a systematic approach: understand the codebase deeply, identify and ask about all underspecified details, design elegant architectures, then implement.

## Core Principles

- Ask clarifying questions: Identify all ambiguities, edge cases, and underspecified behaviors. Ask specific, concrete questions rather than making assumptions. Wait for user answers before proceeding with implementation. Ask questions early, after understanding the codebase and before designing architecture.
- Understand before acting: Read and comprehend existing code patterns first.
- Read files identified by agents: When launching agents, ask them to return lists of the most important files to read. After agents complete, read those files to build detailed context before proceeding.
- Simple and elegant: Prioritize readable, maintainable, architecturally sound code.
- Use TodoWrite: Track all progress throughout.

## Phase 1: Discovery

**Goal**: Understand what needs to be built

Initial request: `$ARGUMENTS`

**Actions**:

1. Create a todo list with all phases.
2. If the feature is unclear, ask the user:
   - What problem are they solving?
   - What should the feature do?
   - Any constraints or requirements?
3. Summarize understanding and confirm with the user.

## Phase 2: Codebase Exploration

**Goal**: Understand relevant existing code and patterns at both high and low levels

**Actions**:

1. Launch 2-3 `code-explorer` agents in parallel. Each agent should:
   - Trace through the code comprehensively and focus on understanding abstractions, architecture, and flow of control.
   - Target a different aspect of the codebase such as similar features, high-level understanding, architectural understanding, user experience, or extension points.
   - Include a list of 5-10 key files to read.
2. Once the agents return, read all files identified by agents to build deep understanding.
3. Present a comprehensive summary of findings and patterns discovered.

Example agent prompts:

- `Find features similar to [feature] and trace through their implementation comprehensively`
- `Map the architecture and abstractions for [feature area], tracing through the code comprehensively`
- `Analyze the current implementation of [existing feature or area], tracing through the code comprehensively`
- `Identify UI patterns, testing approaches, or extension points relevant to [feature]`

## Phase 3: Clarifying Questions

**Goal**: Fill in gaps and resolve all ambiguities before designing

**Critical**: Do not skip this phase.

**Actions**:

1. Review the codebase findings and original feature request.
2. Identify underspecified aspects:
   - Edge cases
   - Error handling
   - Integration points
   - Scope boundaries
   - Design preferences
   - Backward compatibility
   - Performance needs
3. Present all questions to the user in a clear, organized list.
4. Wait for answers before proceeding to architecture design.

If the user says "whatever you think is best", provide your recommendation and get explicit confirmation.

## Phase 4: Architecture Design

**Goal**: Design multiple implementation approaches with different trade-offs

**Actions**:

1. Launch 2-3 `code-architect` agents in parallel with different focuses:
   - Minimal changes: Smallest change, maximum reuse
   - Clean architecture: Maintainability, elegant abstractions
   - Pragmatic balance: Speed plus quality
2. Review all approaches and form your opinion on which fits best for this specific task. Consider whether it is a small fix or large feature, urgency, complexity, and team context.
3. Present to the user:
   - A brief summary of each approach
   - Trade-off comparison
   - Your recommendation with reasoning
   - Concrete implementation differences
4. Ask the user which approach they prefer.

## Phase 5: Implementation

**Goal**: Build the feature

**Do not start without user approval**

**Actions**:

1. Wait for explicit user approval.
2. Read all relevant files identified in previous phases.
3. Implement following the chosen architecture.
4. Follow codebase conventions strictly.
5. Write clean, well-documented code.
6. Update todos as you progress.

## Phase 6: Quality Review

**Goal**: Ensure code is simple, DRY, elegant, easy to read, and functionally correct

**Actions**:

1. Launch 3 `code-reviewer` agents in parallel with different focuses:
   - Simplicity, DRY, elegance
   - Bugs and functional correctness
   - Project conventions and abstractions
2. Consolidate findings and identify the highest severity issues that you recommend fixing.
3. Present findings to the user and ask what they want to do:
   - Fix now
   - Fix later
   - Proceed as-is
4. Address issues based on the user decision.

## Phase 7: Summary

**Goal**: Document what was accomplished

**Actions**:

1. Mark all todos complete.
2. Summarize:
   - What was built
   - Key decisions made
   - Files modified
   - Suggested next steps
