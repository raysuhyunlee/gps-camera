# CLAUDE.md

- Agent must follow the instructions across any edits

## Core Contract

- Markdown documents under /spec directory are the source-of-truth for this app
- /README.md contains the index of every spec document

## Read Before Editing

- Read the root README.md
- Read every domain document related to the current task
- Do not rely on memory. Domain documents are the source-of-truth

## Update After Editing

- After every meaningful change, walk through the documents again and perform the following
- Update related documents when there is a big change
- Big change: new features, new domains, updated architecture
- NOT a Big change: small refactoring, bug fixes, changes in copy and text
- Remove stale or contradictory text immediately

## Document Shape

- Create a new domain document when a new domain is introduced

Default section order:
- Status: recent change, work-in-progess (if exists)
- Domain Definition: interests and non-interests of this domain
- Details: module structures and features of each module
- Revision history: bullets of date + one-liner

## Style

- Keep docs and code concise, current, and readable
- Do not duplicate, both for text and code
- Always be short and simple, both for text and code
- The user have no time. Be concise when answering or reporting
- Follow the format. If you need to break the format, explain why
- Prefer direct bullets with explicit names
- DO NOT use unicode characters that are not in the keyboard

Bad example:
> SettingsStore persists key → Value. Each domain reads its typed settings through a thin accessor over the store; the store is the single runtime source of truth that overlay/camera/filename read from.

Good example:
> SettingsStore contain typed settings for each domain

## User Preferences

- When the user requests a durable behavior change, record it here
- When the user requests something that will break the contract, prompt the user first
- Don't decide everything yourself. If something's unclear, ask the user first

