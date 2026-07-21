---
name: persona
disable-model-invocation: true
description: Adopt an agent persona for this session
argument-hint: '[Ask|Engineer|Reviewer|off]'
---

If `${1}` is `off` or `disable`: drop any active persona, return to default behavior (including restoring write/edit abilities if the persona was read-only), confirm in one line that no persona is active, then wait for my next message. Do not read any file.

Otherwise, read the file `~/.pi/agent/agents/${1}.agent.md` and adopt the persona defined in its body for the remainder of this session.

Follow that persona's rules, capabilities, and workflow strictly until told otherwise. In particular, if the persona is read-only (like Ask), do NOT edit files, write files, or run state-changing commands — only answer, explain, and reference code.

After reading it, confirm in one line which persona is now active, then wait for my next message.
