# Feature Development Plugin

A comprehensive, structured workflow for feature development with specialized agents for codebase exploration, architecture design, and quality review.

## Overview

The Feature Development Plugin provides a systematic 7-phase approach to building new features. Instead of jumping straight into code, it guides you through understanding the codebase, asking clarifying questions, designing architecture, and ensuring quality, resulting in better-designed features that integrate seamlessly with your existing code.

## Philosophy

Building features requires more than just writing code.

- Understand the codebase before making changes
- Ask questions to clarify ambiguous requirements
- Design thoughtfully before implementing
- Review for quality after building

This plugin embeds these practices into a structured workflow that runs automatically when you use the `/feature-dev` command.

## Command: `/feature-dev`

Launches a guided feature development workflow with 7 distinct phases.

### Usage

```bash
/feature-dev Add user authentication with OAuth
```

Or simply:

```bash
/feature-dev
```

The command will guide you through the entire process interactively.

## The 7-Phase Workflow

### Phase 1: Discovery

Goal: Understand what needs to be built

What happens:

- Clarifies the feature request if it's unclear
- Asks what problem you're solving
- Identifies constraints and requirements
- Summarizes understanding and confirms with you

### Phase 2: Codebase Exploration

Goal: Understand relevant existing code and patterns

What happens:

- Launches 2-3 `code-explorer` agents in parallel
- Each agent explores different aspects such as similar features, architecture, or UI patterns
- Agents return comprehensive analyses with key files to read
- Claude reads all identified files to build deep understanding
- Presents a comprehensive summary of findings

### Phase 3: Clarifying Questions

Goal: Fill in gaps and resolve all ambiguities

What happens:

- Reviews codebase findings and the feature request
- Identifies underspecified aspects such as edge cases, error handling, integration points, backward compatibility, and performance needs
- Presents all questions in an organized list
- Waits for your answers before proceeding

### Phase 4: Architecture Design

Goal: Design multiple implementation approaches

What happens:

- Launches 2-3 `code-architect` agents with different design focuses
- Reviews all approaches
- Forms an opinion on which approach best fits the task
- Presents trade-offs and a recommendation
- Asks which approach you prefer

### Phase 5: Implementation

Goal: Build the feature

What happens:

- Waits for explicit approval before starting
- Reads all relevant files identified in previous phases
- Implements following the chosen architecture
- Follows codebase conventions strictly
- Writes clean, well-documented code
- Updates todos as progress is made

### Phase 6: Quality Review

Goal: Ensure code is simple, DRY, elegant, and functionally correct

What happens:

- Launches 3 `code-reviewer` agents in parallel with different focuses
- Consolidates findings
- Identifies highest severity issues
- Presents findings and asks what you want to do
- Addresses issues based on your decision

### Phase 7: Summary

Goal: Document what was accomplished

What happens:

- Marks all todos complete
- Summarizes what was built, key decisions, files modified, and suggested next steps
