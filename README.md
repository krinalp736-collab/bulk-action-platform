# Bulk Action Platform

A production-grade bulk action platform for a CRM, built for the Shipmnts backend technical
assignment. Ships one mandatory action (Bulk Update on `Contact`) plus a second
(`Bulk Archive`) included specifically to prove the extensibility story, and all three optional
enhancements: per-account rate limiting, email de-duplication, and scheduled runs.

**Read [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) first** — it explains every design decision
(why the schema looks like this, how the two-phase job pipeline avoids a real race condition, why
rate limiting uses a sliding-window approximation, etc.). This README only covers setup and API
surface.

## Stack

- Ruby 3.3.7 / Rails 8.1.3 (API-only)
- PostgreSQL (jsonb columns, window functions for de-duplication)
- Sidekiq 8 + Redis (batch processing, rate limiting, scheduling)
- RSpec + FactoryBot

## Setup

### Prerequisites

- Ruby 3.3.7 (a `.ruby-version` file is present; use rbenv/rvm/asdf)
- PostgreSQL 12+ with `libpq-dev`/headers available (the `pg` gem needs them to build)
- Redis 6.2+ (Sidekiq 8's client requires the `HELLO` command, added in Redis 6) — see the
  environment note below if you're on an older Redis

### Install

```bash
bundle install
cp .env.example .env               # adjust REDIS_URL etc. if needed
bin/rails db:create db:migrate
bin/rails db:seed                  # loads db/seeds/contacts.csv (~2,000 demo contacts)
```

### Run

Three processes, three terminals:

```bash
bin/rails server                        # API on http://localhost:3000
bundle exec sidekiq -C config/sidekiq.yml  # background workers
redis-server                            # if not already running
```

### Test

```bash
bundle exec rspec
```

94 examples covering models, services (registry, strategies, filter query, rate limiter), both
jobs (including multi-batch and idempotency-under-redelivery scenarios), and full request specs.

## Environment variables

| Variable | Default | Purpose |
|---|---|---|
| `REDIS_URL` | `redis://localhost:6379/1` | Sidekiq + rate limiter |
| `SIDEKIQ_CONCURRENCY` | 10 | Sidekiq worker threads (dev/test); keep ≤ `RAILS_MAX_THREADS` |
| `RAILS_MAX_THREADS` | 10 | DB connection pool size — must be ≥ Sidekiq concurrency |
| `BULK_ACTION_BATCH_SIZE` | 1000 | Entities per batch job |
| `BULK_ACTION_MAX_CONTACT_IDS` | 10000 | Cap on the explicit `contact_ids` targeting path |
| `BULK_ACTION_RATE_LIMIT_PER_MINUTE` | 10000 | Per-account processed-rows/minute cap |

## API

Full request/response examples for every endpoint (including the validation-error, rate-limit,
de-dup, and scheduling scenarios) are in
[`postman/BulkActionPlatform.postman_collection.json`](postman/BulkActionPlatform.postman_collection.json)
— import it, set `base_url`, and run top to bottom.

| Method | Path | Purpose |
|---|---|---|
| `POST` | `/bulk-actions` | Create a bulk action (see body shape below) |
| `GET` | `/bulk-actions` | List, filter by `?account_id=`/`?status=` |
| `GET` | `/bulk-actions/:id` | Full record |
| `GET` | `/bulk-actions/:id/stats` | Counts + `percentage_complete` + running status |
| `GET` | `/bulk-actions/:id/logs` | Per-entity logs, filter by `?status=`, keyset-paginated via `?after=` |
| `PATCH` | `/bulk-actions/:id/cancel` | Cooperative cancellation (not in the original spec — added because the `cancelled` status needs some way to actually be reached) |

`POST /bulk-actions` body:

```json
{
  "bulk_action": {
    "account_id": "acc_demo",
    "entity_type": "Contact",
    "action_type": "bulk_update",
    "filter": { "status": "lead" },
    "payload": { "status": "active" },
    "scheduled_at": null
  }
}
```

- Target via **either** `filter` (whitelisted: `status`, `age`, `name`, `email`) **or**
  `contact_ids` (array, capped at `BULK_ACTION_MAX_CONTACT_IDS`) — not both.
- `payload` keys are whitelisted per `action_type` (`ContactBulkUpdate` allows `name`/`email`/
  `age`/`status`; `ContactBulkArchive` needs none).
- `scheduled_at` (optional, ISO8601): if present and in the future, the run is deferred via
  Sidekiq's native scheduling instead of starting immediately.

## Docker

`Dockerfile` (Rails 8's default multi-stage build — already includes `libpq-dev` for the `pg`
gem) and `docker-compose.yml` (Postgres + Redis + a `web` service + a `worker` service running
`bundle exec sidekiq` from the same image) are included.

```bash
docker compose up --build
docker compose exec web bin/rails db:seed
```

**This was not runnable in the sandbox this was built in** (no `docker` binary available there —
see the environment note below) and so is not locally verified end-to-end, unlike everything
else in this README. The Dockerfile itself is Rails' own generated production Dockerfile
(unmodified) plus a `docker-compose.yml` layering Postgres/Redis/a worker service on top, both
built from patterns that are otherwise standard — flagging the lack of a build/run test here
rather than silently claiming it was verified.

## Development environment note

Two things in the sandbox this was built in were older than the app targets, worth calling out so
nothing here reads as untested-and-hoping-for-the-best:

- **PostgreSQL wasn't installed at all** (no server, no `libpq-dev`) — installed via
  `apt-get install postgresql postgresql-contrib libpq-dev` partway through the build. Runs on
  Postgres 10.23 here (Ubuntu 18.04's repo default); anything 12+ is recommended for a real
  deployment, but nothing in this app uses a version-specific feature Postgres 10 lacks.
- **The system's Redis was 4.0.9** — Sidekiq 8's `redis-client` requires Redis 6.2+ (the `HELLO`
  command). Rather than pin this project to an old Sidekiq just to match one sandbox's Redis, a
  current Redis was built from source and run locally on a separate port, purely for local
  development/testing in that environment. **This is not part of the shipped app**: `.env.example`,
  `config/initializers/sidekiq.rb`'s default, and `docker-compose.yml` all assume a normal, current
  Redis on the standard port — nothing about the production code path assumes this workaround.

Every RSpec example, and every endpoint in the Postman collection, was actually run against real
Postgres and real Sidekiq+Redis (not mocked) before being called done.

## Assumptions and trade-offs

The short version — full reasoning in [`docs/ARCHITECTURE.md` §13](docs/ARCHITECTURE.md#13-assumptions-and-explicit-trade-offs):

- "Bulk Update" = one field-change payload applied to a filtered/selected set of existing rows,
  not per-row-differing updates (that's a distinct CSV-import/upsert feature, out of scope).
- No real `accounts`/auth model — `account_id` is trusted as given; a real system would derive it
  from an authenticated session.
- Rate limit is a single global constant, not per-account-configurable.
