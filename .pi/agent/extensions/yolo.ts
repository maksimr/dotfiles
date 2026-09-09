// yolo.ts — `pi --yolo` auto-approves pi-permission-system "ask" prompts for this run.
//
// Registers a "yolo" authorizer-chain link via the permission system's
// cross-extension service (Symbol.for-backed globalThis map). The link only
// exists when the flag is set; without --yolo nothing changes. Requires
// "authorizerChain": ["yolo"] in the pi-permission-system config.
//
// ponytail: allow on path/external_directory surfaces is capped to defer by
// the permission system's delegation envelope, so those asks still prompt.

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

type AuthorizerVerdict =
  | { kind: "allow" }
  | { kind: "deny"; reason?: string }
  | { kind: "defer" };

interface PermissionsService {
  registerAuthorizer(
    name: string,
    authorize: (...args: unknown[]) => Promise<AuthorizerVerdict>,
  ): () => void;
}

const SESSION_SERVICES_KEY = Symbol.for(
  "@gotgenes/pi-permission-system:session-services",
);

export default function (pi: ExtensionAPI) {
  pi.registerFlag("yolo", {
    description:
      "Auto-approve pi-permission-system permission asks for this run",
    type: "boolean",
    default: false,
  });

  let dispose: (() => void) | undefined;

  // permissions:ready fires at least once per session and may repeat; guard on
  // the stored disposer so re-registration (duplicate-name throw) is avoided.
  pi.events.on("permissions:ready", (data) => {
    if (pi.getFlag("yolo") !== true || dispose) return;
    const sessionId = (data as { sessionId?: string | null }).sessionId;
    if (!sessionId) return;
    const services = (globalThis as Record<symbol, unknown>)[
      SESSION_SERVICES_KEY
    ] as Map<string, PermissionsService> | undefined;
    const permissions = services?.get(sessionId);
    if (!permissions) return;
    dispose = permissions.registerAuthorizer("yolo", async () => ({
      kind: "allow" as const,
    }));
  });

  pi.on("session_start", (_event, ctx) => {
    if (pi.getFlag("yolo") === true) {
      ctx.ui.setStatus("yolo", "\x1b[32m⚡yolo\x1b[0m");
    }
  });

  pi.on("session_shutdown", () => {
    dispose?.();
    dispose = undefined;
  });
}
