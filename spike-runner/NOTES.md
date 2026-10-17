# Runner design pass: throwaway spike (backup branch only, never landed)

Design notes live in scratchpad/runner/design.md (copied here as design.md when ready).

## Timing spike (timing.exs), Elixir 1.20.4 / OTP 28, 4 cores, 2026-10-17
- abs timers (Process.send_after abs: true on a 10 ms grid): idle p50 ~0.2 ms late,
  p99 0.6-0.8 ms, max 3-8 ms, no early wakes in 4000 wakes.
- relative send_after(10) after each cycle: ~11 ms per cycle, 1067 ms drift in 1000
  cycles, 106 false overlap periods. Use absolute deadlines.
- under a full mix test beside it: p50 1.8 ms, p99 126 ms, max 196 ms (normal priority);
  :high priority p50 0.5 ms, p99 167 ms, max 237 ms.
- cycle/3 of the 4.4 plant: p50 ~0.1 ms, p99 0.2-0.4 ms, p99.9 up to 2-10 ms.
