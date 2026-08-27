# ⚡ VoltRide — E-Bike Store (multi-repo microservices demo)

VoltRide is a demo e-commerce site that sells e-bikes, built as **seven repositories in three languages** that call each other over HTTP. This repo is the umbrella: system documentation plus scripts that clone and run everything.

Like many real-world microservice estates, every repo defines its **own local copies** of the request/response shapes it sends and expects (TypeScript interfaces, Go structs, Pydantic models). There is no shared types package and no OpenAPI codegen — repos are only coupled through their HTTP contracts at runtime, so changing a contract means coordinated PRs across every consumer repo (each repo's `AGENTS.md` maps its producers and consumers).

## The repos

| Repo | Stack | Port | Responsibility |
|---|---|---|---|
| [voltride-frontend](https://github.com/coderabbit-demo/voltride-frontend) | React + TS (Vite) | 5173 | Storefront UI |
| [voltride-catalog](https://github.com/coderabbit-demo/voltride-catalog) | Node/TS (Express) | 4001 | Products; enriches with stock + pricing |
| [voltride-cart](https://github.com/coderabbit-demo/voltride-cart) | Node/TS (Express) | 4002 | Carts; enriches with product info + totals |
| [voltride-inventory](https://github.com/coderabbit-demo/voltride-inventory) | Go (stdlib) | 4003 | Stock + reservations (leaf service) |
| [voltride-orders](https://github.com/coderabbit-demo/voltride-orders) | Go (stdlib) | 4004 | Checkout orchestrator — calls 4 services |
| [voltride-pricing](https://github.com/coderabbit-demo/voltride-pricing) | Python (FastAPI) | 4005 | Quotes: discounts, surcharges, tax, shipping |
| [voltride-notifications](https://github.com/coderabbit-demo/voltride-notifications) | Python (FastAPI) | 4006 | Simulated confirmation emails |

### Call graph

```
frontend ─→ catalog ─┬─→ inventory                      (stock badges)
                     └─→ pricing ─→ inventory           (display price; stock-based rules)
frontend ─→ cart ────┬─→ catalog                        (product summary: validate, name, basePrice)
                     └─→ pricing ─→ inventory           (cart totals)
frontend ─→ orders ──┬─→ cart ─→ catalog                (fetch cart at checkout)
                     ├─→ inventory                      (reserve stock; rollback on failure)
                     ├─→ pricing ─→ inventory           (final quote)
                     └─→ notifications ─→ catalog       (confirmation "email" with product names)
frontend ─→ notifications                               (render sent email on confirmation page)
```

All data is in-memory and seeded at startup — no databases, no Docker. `POST localhost:4003/api/admin/reset` reseeds inventory after demo checkouts.

## Running the whole system

Prerequisites: macOS/Linux with **Node ≥ 20** and **Python ≥ 3.9**. Go is installed automatically (via Homebrew) if missing.

```sh
git clone https://github.com/coderabbit-demo/voltride-platform.git
cd voltride-platform
./scripts/start.sh     # or: npm start
```

The script clones any missing sibling repo next to this checkout, installs whatever is missing (Go, Python venvs, npm deps), sweeps stale processes off the ports, and starts all 7 processes with `concurrently`. Open **http://localhost:5173**.

Ctrl+C stops everything (the script sweeps the ports on exit). If ports are ever stuck, `npm run stop` kills VoltRide processes only — it never touches another app that happens to share a port.

### Smoke-test with curl

```sh
curl -s localhost:4003/api/stock/volt-vaquero                     # inventory
curl -s localhost:4005/api/quotes -H 'Content-Type: application/json' \
  -d '{"items":[{"productId":"watt-wanderer","basePriceCents":299900,"quantity":1}],"promoCode":null}'
curl -s localhost:4001/api/products                               # catalog (→ inventory)
CART=$(curl -s -X POST localhost:4002/api/carts | sed 's/.*"cartId":"\([^"]*\)".*/\1/')
curl -s localhost:4002/api/carts/$CART/items -H 'Content-Type: application/json' \
  -d '{"productId":"volt-vaquero","quantity":1}'                  # cart (→ catalog + pricing)
curl -s localhost:4004/api/orders -H 'Content-Type: application/json' \
  -d "{\"cartId\":\"$CART\",\"customerName\":\"Ada Lovelace\",\"customerEmail\":\"ada@example.com\",\"shippingAddress\":{\"line1\":\"1 Analytical Way\",\"city\":\"Portland\",\"postalCode\":\"97201\",\"country\":\"US\"}}"
curl -s -X POST localhost:4003/api/admin/reset                    # restore stock
```
