import type { ExtensionAPI } from '@earendil-works/pi-coding-agent';

// sanitizeSystemPrompt is copied from https://github.com/Rahularya01/pi-antigravity
// (src/stream/stream.ts, MIT, Copyright (c) 2026 Rahul Arya).
// Antigravity answers system prompts that identify pi with a fake 429 RESOURCE_EXHAUSTED.

const NEUTRAL_OPENER = 'You are a coding agent helping the user with their project.';

export function sanitizeSystemPrompt(text: string): string {
  return text
    .replace(
      /^You are a coding assistant running inside [^.]*\.\s*Help users inspect files, run commands, and modify code\./i,
      NEUTRAL_OPENER,
    )
    .replace(
      /running inside pi-bolt,\s*a build of pi\s*\(a coding agent harness\)\s*compiled ahead of time/gi,
      'running inside your development environment',
    )
    .replace(
      /inside pi-bolt,\s*a build of pi\s*\(a coding agent harness\)\s*compiled ahead of time/gi,
      'inside your development environment',
    )
    .replace(/running inside pi(?:-bolt)?,\s*a coding agent harness/gi, 'running inside your development environment')
    .replace(/inside pi(?:-bolt)?,\s*a coding agent harness/gi, 'inside your development environment')
    .replace(
      /(coding assistant )running inside pi(?:-bolt)?(?=[.,!?;:\s]|$)(?!\.\w)/gi,
      '$1running inside your development environment',
    )
    .replace(/(coding agent )inside pi(?:-bolt)?(?=[.,!?;:\s]|$)(?!\.\w)/gi, '$1inside your development environment')
    .replace(/\bpractical,\s*and tool-aware\./gi, 'practical, and tool aware.')
    .replace(/codemode scripts and non-LLM models/gi, 'codemode scripts (docs/codemode.md), non-LLM models');
}

export default function (pi: ExtensionAPI) {
  pi.on('before_provider_request', (event, ctx) => {
    if (ctx.model?.provider !== 'antigravity') return;
    const payload = event.payload as {
      config?: { systemInstruction?: unknown; thinkingConfig?: { thinkingLevel?: string } };
    };
    const config = { ...payload.config };
    if (typeof config.systemInstruction === 'string') {
      config.systemInstruction = sanitizeSystemPrompt(config.systemInstruction);
    }
    // Pi's Gemini API stops at HIGH; models.json maps xhigh to high only for models that take XHIGH.
    if (config.thinkingConfig?.thinkingLevel && ctx.model.thinkingLevelMap?.xhigh && pi.getThinkingLevel() === 'xhigh') {
      config.thinkingConfig = { ...config.thinkingConfig, thinkingLevel: 'XHIGH' };
    }
    return { ...payload, config };
  });
}
