
# ---------------------------------------------------------------------------
# Async rendering -- placeholder for M5.
# Splits prompt work into cheap (sync) and expensive (async); refreshes the
# prompt on the next cycle when the slow info is ready. See
# docs/adr/ADR-0005-async-rendering.md for the deferred-on-next-prompt
# tradeoff and the limitations accepted.
# ---------------------------------------------------------------------------
