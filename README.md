# Deploy and Host

[![Deploy on Railway](https://railway.app/button.svg)](https://railway.com/deploy/opentrader)

OpenTrader is a self-hosted cryptocurrency trading bot with built-in DCA, Grid, and RSI strategies, a polished web UI, and support for 100+ exchanges via CCXT. This template builds the bot from source (pinned to `v1.0.0-beta.29`), runs database migrations on boot, and serves the web UI on a single port.

After deploying, open your service URL and log in with:

- **Email:** `onboarding@opentrader.pro`
- **Password:** the value you set for `ADMIN_PASSWORD`

## About Hosting

The template runs a single service that bundles the trading engine, the tRPC API server, and the web frontend. State is stored in an embedded SQLite database at `/app/data/opentrader.db`, persisted on a Railway volume — no external database service is required.

Key environment variables:

- `ADMIN_PASSWORD` (required) — UI login password. Auto-generated per deployment via `${{secret(16)}}`; log in with email `onboarding@opentrader.pro` and this generated value (visible in the service's Variables tab).
- `DATABASE_URL` — SQLite file path, wired to the persistent volume via `file:${{RAILWAY_VOLUME_MOUNT_PATH}}/opentrader.db`

`PORT` (4000) and `HOST` (0.0.0.0) are pinned in the image — no configuration needed. Exchange API keys are **not** stored in environment variables. You add exchange accounts (OKX, BYBIT, BITGET, BINANCE, KRAKEN, COINBASE, GATEIO, and more via CCXT) inside the web UI after login, and they are stored encrypted in the SQLite database on your own volume.

## Why Deploy

- **Self-custody**: your exchange API keys and trading history live on your own Railway volume, not on a third-party SaaS.
- **Zero external dependencies**: the bot ships with an embedded database and needs only one container — the whole stack is one service.
- **Always-on trading**: DCA and grid strategies run 24/7 in the cloud instead of your laptop.
- **One-click updates**: the image is pinned to a release tag (`v1.0.0-beta.29`) so redeploys are reproducible.

## Common Use Cases

- **DCA bots** — accumulate BTC/ETH on a schedule with configurable take-profit targets.
- **Grid trading** — profit from sideways markets with configurable grid levels and price ranges.
- **RSI strategy** — buy oversold / sell overbought with persistence-based trend detection.
- **Backtesting** — validate strategies against historical candles before risking funds.
- **Custom strategies** — drop your own TypeScript strategy files and load them via `CUSTOM_STRATEGIES_PATH`.

## Dependencies for OpenTrader

### Deployment Dependencies

- A Railway account with a starter plan or above (the container needs ~0.5 GB RAM).
- A Railway volume is attached automatically at `/app/data` for the SQLite database.
- Optional: exchange API keys with spot-trading permission for the exchange you configure in the UI.
- Optional: a custom strategies directory on the volume if you use `CUSTOM_STRATEGIES_PATH`.

## Links

- [OpenTrader on GitHub](https://github.com/Open-Trader/opentrader)
- [Documentation](https://opentrader.github.io/)
- [Community Discord](https://discord.gg/RS7y3ffvvG)
- [License (Apache-2.0)](https://github.com/Open-Trader/opentrader/blob/dev/LICENSE)