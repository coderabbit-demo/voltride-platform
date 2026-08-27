# AGENTS.md — voltride-platform (system map)

VoltRide is a multi-repo microservices demo: seven repos in three languages coupled only through HTTP contracts. This umbrella repo holds the docs and orchestration scripts; the master producer→consumer map below is the system's source of truth.

## The one rule that matters: contracts are duplicated per repo, on purpose

There is **no shared types package** anywhere in VoltRide and there must never be one. Every repo hand-maintains its own local copies of the shapes it sends and expects. No compiler, type-checker, or test suite spans a repo boundary — **a wire-format change in a producer repo compiles and runs perfectly there and only breaks its consumers at runtime, in other repositories.** Changing a contract therefore requires coordinated PRs in every consumer repo, linked from the producer PR.

## Master producer→consumer map

| Producer repo | Contract | Consumer repos (files) |
|---|---|---|
| voltride-inventory | stock records (`stockCount`, `restockEtaDays`) | voltride-catalog (`src/types.ts`, `src/clients/inventoryClient.ts`), voltride-pricing (`inventory_client.py`), voltride-orders (`clients.go`) |
| voltride-inventory | reservations (`status: "reserved"`, 409 body) | voltride-orders (`clients.go`) |
| voltride-catalog | `GET /api/products/:id/summary` | voltride-cart (`src/clients/catalogClient.ts`), voltride-notifications (`catalog_client.py`) |
| voltride-catalog | product list/detail | voltride-frontend (`src/api/catalog.ts`) |
| voltride-pricing | quotes (integer `*Cents` fields, `discountPercent` sign) | voltride-catalog, voltride-cart (`src/clients/pricingClient.ts`), voltride-orders (`clients.go`) |
| voltride-cart | cart response (`items[]`, `promoCode`, `totals`), `DELETE /api/carts/:id`, 404 body | voltride-orders (`clients.go`), voltride-frontend (`src/api/cart.ts`) |
| voltride-orders | order response + 409/422 bodies | voltride-frontend (`src/api/orders.ts`) |
| voltride-orders | confirmation payload | voltride-notifications (`main.py`, strict Pydantic — drift → 422 → every checkout fails) |
| voltride-notifications | notification records | voltride-frontend (`src/api/notifications.ts`) |

Failure-mode asymmetry worth knowing: strict Pydantic consumers fail **loudly** (422), TypeScript consumers surface `undefined`/NaN, but **Go consumers fail silently** — missing or renamed JSON keys decode as zero values with no error, which makes them the most dangerous consumers to miss.

## Conventions (system-wide)

- In-memory data only; inventory reseeds via `POST /api/admin/reset`.
- Peer URLs are env vars with localhost defaults (`INVENTORY_URL`, `CATALOG_URL`, `PRICING_URL`, `CART_URL`, `NOTIFICATIONS_URL`).
- Money is integer cents, field names end in `Cents`; errors are JSON `{"error": "snake_case_code"}`.
- The frontend reaches services only through its Vite proxy and never calls inventory or pricing directly.

## Running and verifying

```sh
./scripts/start.sh     # clone missing siblings, install prereqs, start all 7 processes
npm run stop           # kill all VoltRide processes if ports are stuck
```

Health checks on ports 4001–4006 (`GET /health`); UI at http://localhost:5173. End-to-end: use the curl block in `README.md` or click through browse → detail → cart → checkout → confirmation.
