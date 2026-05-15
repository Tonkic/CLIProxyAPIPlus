# SDK Watcher Integration

The SDK service exposes a watcher integration that surfaces granular auth updates without forcing a full reload.

## Update Queue Contract

- `watcher.AuthUpdate` represents one credential change. `Action` may be `add`, `modify`, or `delete`.
- `WatcherWrapper.SetAuthUpdateQueue(chan<- watcher.AuthUpdate)` wires the service queue into the watcher.
- The service creates the queue in `ensureAuthUpdateQueue` with a buffered channel and a consumer goroutine.

## Watcher Behavior

`internal/watcher/watcher.go` keeps a shadow snapshot of auth state. Filesystem or config events trigger recomputation and a diff against the previous snapshot. The watcher emits minimal auth updates for adds, edits, and removals.

Updates are coalesced per credential identifier. If several changes happen before dispatch, only the latest state is sent downstream.

## Burst Handling

- Watcher dispatch and service consumption run independently.
- The dispatch buffer coalesces repeated updates for the same credential.
- The service queue absorbs normal bursts and drains backlog in a loop.
- If the queue is saturated for a long time, updates keep merging so the latest state is eventually applied.

## Usage Checklist

1. Build the SDK service.
2. Create the auth update queue before starting the watcher.
3. Call `SetAuthUpdateQueue` on the watcher wrapper.
4. Start the watcher with a reload callback for config updates.
5. Let auth deltas flow through `handleAuthUpdate` instead of forcing full reloads.
