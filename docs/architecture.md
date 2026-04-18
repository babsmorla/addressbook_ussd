# USSD Ruby Template — Architecture Guide

> **Apps-N-Mobile V2 Modular Standard**
> This document is the single source of truth for how the USSD Ruby template is structured, how data flows through it, and how to scale it with new modules.

---

## Table of Contents

1. [Overview](#overview)
2. [Directory Structure](#directory-structure)
3. [Request Lifecycle](#request-lifecycle)
4. [The State Machine](#the-state-machine)
5. [Layer-by-Layer Breakdown](#layer-by-layer-breakdown)
   - [config/](#config)
   - [util/](#util)
   - [helpers/](#helpers)
   - [models/](#models)
   - [controller/session/](#controllersession)
   - [controller/dial/](#controllerdial)
   - [controller/menu/](#controllermenu)
   - [controller/page/](#controllerpage)
   - [controller/service/](#controllerservice)
6. [Constants Reference](#constants-reference)
7. [Adding a New Module](#adding-a-new-module)
8. [Adding a New Page to an Existing Module](#adding-a-new-page-to-an-existing-module)
9. [Pagination](#pagination)
10. [API Integration](#api-integration)
11. [Environment Variables](#environment-variables)
12. [Boot Sequence & Load Order](#boot-sequence--load-order)
13. [Testing Locally](#testing-locally)
14. [Deployment](deployment.md)
15. [Session Resume](#session-resume)
16. [Payment Processing Pattern](#payment-processing-pattern)
    - [Telco Payload Fields](#telco-payload-fields)
    - [The `nw_code` Field](#the-nw_code-field)
    - [MTN Timing Constraint](#mtn-timing-constraint)
17. [Common Pitfalls](#common-pitfalls)

---

## Overview

This is a **Ruby/Sinatra** USSD gateway application. It receives JSON POST requests from a Telco gateway and returns JSON responses that display menus on a subscriber's phone.

**Key design decisions:**

| Decision | Rationale |
|---|---|
| **No database** | Redis is the only persistence layer — sessions are ephemeral (5-minute TTL). |
| **Registry-based routing** | New pages are added to a hash, not hardcoded in a `case` statement. Scales linearly. |
| **REQUEST / RESPONSE per page** | Each page knows how to render itself *and* process the user's input. Self-contained. |
| **JSON-only responses** | Every response goes through `Session::Manager` to guarantee valid gateway JSON. |

---

## Directory Structure

```
ussd-ruby-template/
├── app.rb                        # Sinatra entry point — defines POST '/' route
├── config.ru                     # Rack config — boots app.rb via Puma
├── Gemfile                       # Ruby dependencies
├── .ruby-version                 # RVM Ruby version lock
├── .ruby-gemset                  # RVM gemset name
├── .gitignore                    # Git ignore rules
├── CLAUDE.md                     # AI assistant context file
│
├── config/                       # Infrastructure configuration
│   ├── logger.rb                 # LOGGER — daily-rotating file logger
│   └── redis.rb                  # $redis — global Redis client
│
├── util/                         # Stateless standalone utilities
│   ├── constants.rb              # All app-wide constants
│   └── api/
│       └── base.rb               # Faraday HTTP client wrapper (Util::Api::Base)
│
├── helpers/                      # Session-aware mixins (included into pages)
│   ├── pagination.rb             # Pagination module for long lists
│   ├── validations.rb            # Menu validations
│   └── formatters.rb             # UI formatting
│
├── models/                       # Data models
│   └── cache.rb                  # Cache — Redis session store (Cache.store / Cache.fetch)
│
├── controller/
│   ├── init.rb                   # Strict load order for all controller files
│   │
│   ├── session/                  # Gateway JSON response layer
│   │   ├── base.rb               # Session::Base — constructor
│   │   └── manager.rb            # Session::Manager — continue() / end()
│   │
│   ├── dial/                     # Entry point — receives raw JSON from gateway
│   │   └── manager.rb            # Dial::Manager — routes msg_type 0/1/2
│   │
│   ├── menu/                     # State machine core
│   │   ├── base.rb               # Menu::Base — fetch_data, store_data, render_page
│   │   ├── manager.rb            # Menu::Manager — reads tracker, dispatches to page
│   │   └── registry.rb           # MENU_MANAGER hash — the central routing table
│   │
│   ├── page/                     # UI screens
│   │   ├── base.rb               # Page::Base — REQUEST/RESPONSE dispatcher
│   │   ├── contact_us.rb         # Page::ContactUs — shared across all modules
│   │   └── gen/                   # "gen" = default/generic module
│   │       ├── main_menu.rb      # Page::Gen::MainMenu — root menu
│   │       ├── payment.rb        # Page::Gen::Payment — enter amount
│   │       └── summary.rb        # Page::Gen::Summary — confirm & pay
│   │
│   └── service/                  # Business logic layer
│       ├── base.rb               # Service::Base — process(action, params, data = nil) pattern
│       └── gen.rb                # Service::Gen — make_payment via ExternalApi
│
├── log/                          # Runtime logs (gitignored)
│   └── application.log
│
├── tmp/                          # Server restart trigger
│   └── .gitkeep
│
└── docs/                         # This documentation
    └── architecture.md
```

---

## Request Lifecycle

Every USSD interaction follows this exact path:

```
┌─────────────────────────────────────────────────────────────┐
│                     TELCO GATEWAY                           │
│  Sends POST / with JSON:                                    │
│  { msisdn, msg_type, ussd_body, session_id }                │
└───────────────────────┬─────────────────────────────────────┘
                        │
                        ▼
┌───────────────────────────────────────┐
│           app.rb — POST '/'           │
│  Dial::Manager.new(request.body).process │
└───────────────────────┬───────────────┘
                        │
                        ▼
┌───────────────────────────────────────┐
│          Dial::Manager                │
│                                       │
│  msg_type '0' → first_dial           │
│            └→ Page::Gen::MainMenu    │
│               (activity_type: REQUEST)│
│                                       │
│  msg_type '1' → Menu::Manager        │
│            └→ reads tracker from Redis│
│            └→ dispatches to page      │
│                                       │
│  msg_type '2' → release (cleanup)    │
└───────────────────────┬───────────────┘
                        │
                        ▼
┌───────────────────────────────────────┐
│          Menu::Manager                │
│                                       │
│  1. fetch_data() — reads Redis cache  │
│  2. tracker = @data[:tracker]         │
│  3. function = tracker[:function]     │
│  4. MENU_MANAGER[function].process()  │
└───────────────────────┬───────────────┘
                        │
                        ▼
┌───────────────────────────────────────┐
│          Page::* (e.g. MainMenu)       │
│                                       │
│  activity_type == REQUEST:            │
│    → render_current_page              │
│    → stores tracker in Redis          │
│    → returns JSON via continue()      │
│                                       │
│  activity_type == RESPONSE:           │
│    → process_response                 │
│    → reads @ussd_body (user input)    │
│    → routes to next page or end       │
└───────────────────────┬───────────────┘
                        │
                        ▼
┌───────────────────────────────────────┐
│        Session::Manager               │
│                                       │
│  continue() → msg_type '1' (show menu)│
│  end()      → msg_type '2' (close)   │
│                                       │
│  Returns: JSON string to gateway      │
│  { msisdn, msg_type, ussd_body, ... } │
└───────────────────────────────────────┘
```

---

## The State Machine

The entire application is a **state machine** driven by a `tracker` object stored in Redis.

### The Tracker

```ruby
tracker = {
  function:      'make_payment',    # Which page class to dispatch to
  page:          '2',               # Sub-page number (for multi-step flows)
  activity_type: 'response'         # What to do next: show screen or process input
}
```

The tracker is stored inside the session cache via `store_data(tracker: tracker)` and read back on every subsequent request via `fetch_data`.

### msg_type Values

| Value | Meaning | Action |
|-------|---------|--------|
| `'0'` | **First Dial** — user dialed the USSD shortcode | Show main menu |
| `'1'` | **Continue** — user entered input on an existing session | Read tracker, dispatch to the correct page |
| `'2'` | **Release** — gateway is ending the session | Clean up Redis |

---

## Layer-by-Layer Breakdown

### `config/`

**Purpose:** Infrastructure that must load before anything else.

| File | What it creates | Notes |
|------|-----------------|-------|
| `logger.rb` | `LOGGER` (global constant) | Daily-rotating log file at `log/application.log`. Keeps 3 days. |
| `redis.rb` | `$redis` (global variable) | Connects to `127.0.0.1:6379` by default. Override with `REDIS_HOST`, `REDIS_PORT`, `REDIS_DB` env vars. |

---

### `util/`

**Purpose:** Stateless, standalone tools. These have **zero knowledge** of the USSD session, pages, or Redis state. Pure functions you can call from anywhere.

| File | Class | Usage |
|------|-------|-------|
| `constants.rb` | *(top-level constants)* | `REQUEST`, `RESPONSE`, `BACK`, `NEXT`, `MAINMENU`, `CURRENCY`, etc. |
| `api/base.rb` | `Util::Api::Base` | Faraday HTTP wrapper with 10s timeout. `Util::Api::Base.new(url).post(path, body)` |

**Key rule:** If it needs `@params` or page state → it does NOT belong in `util/`. Put it in `helpers/` instead.

---

### `helpers/`

**Purpose:** Session-aware **mixins** that are `include`d into page classes. They operate on session context (`@data`, `@ussd_body`, `@tracker`).

| File | Module | Methods |
|------|--------|---------|
| `pagination.rb` | `Pagination` | `paginate(collection, page:, per_page:)`, `nav_options(paged)`, `resolve_page(input, current:)` |
| `validations.rb` | `Validations` | Included into Menu::Base for validating msidn, amounts, empty checks, and regex matchers. |
| `formatters.rb` | `Formatters` | Included into Menu::Base for standard text representations. |

**Usage in a page:**

```ruby
class MyPage < Page::Base
  include Pagination

  def render_current_page
    paged = paginate(@data[:items], page: @data[:tracker][:page].to_i)
    message = "Select:\n"
    paged.each_with_index { |item, i| message += "#{i + 1}. #{item[:name]}\n" }
    message += nav_options(paged)
    continue(render_page(function: MY_MODULE, page: paged.current_page))
  end
end
```

**Key rule:** `util/` = call directly (`Util::Validation.method`). `helpers/` = `include` into your page class.

---

### `models/`

**Purpose:** Data persistence layer.

| File | Class | Methods |
|------|-------|---------|
| `cache.rb` | `Cache` | `Cache.store(params)` — saves to Redis with 5-min TTL. `Cache.fetch(params)` — retrieves from Redis. `Cache.find_previous_session(msisdn, current_session_id)` — checks for a resumable session. `Cache.migrate_session(msisdn, old_data, new_session_id)` — copies old session into a new one. |

**Redis key format:**
- Session data: `{session_id}-{msisdn}-cache`
- Last session pointer: `{msisdn}-last-session` → stores the last `session_id` (for resume)

**What gets stored:** A JSON hash containing the `tracker` and any data your pages `store_data()` into it (amounts, selections, API responses, etc.).

---

### `controller/session/`

**Purpose:** Guarantees every response to the gateway is valid JSON. **No page should ever return a raw string.**

| File | Class | Role |
|------|-------|------|
| `base.rb` | `Session::Base` | Constructor. Extracts `msg_type`, `ussd_body`, `display_message`. |
| `manager.rb` | `Session::Manager` | `continue(params)` → sets `msg_type: '1'`, wraps `display_message` into `ussd_body`. `end(params)` → sets `msg_type: '2'`. Returns `.to_json`. |

**Critical rule:** Pages call `continue(message)` or `end_session(message)` — these delegate to `Session::Manager`. The page never constructs JSON directly.

**Echo rule (gateway contract):** `parse_response` does `@params.to_json` — it serialises the entire params hash. Only `ussd_body` and `msg_type` are overwritten. `session_id`, `msisdn`, `nw_code`, and `service_code` are echoed back unchanged automatically. Never strip these fields from `@params` — the gateway requires them in every response.

```ruby
def parse_response(msg_type)
  @params[:ussd_body] = @display_message  # your menu text
  @params[:msg_type]  = msg_type          # '1' continue / '2' end
  @params.to_json                         # session_id, msisdn, nw_code, service_code ride along untouched
end
```

---

### `controller/dial/`

**Purpose:** The absolute entry point. Receives raw JSON from the gateway and routes based on `msg_type`.

```ruby
# dial/manager.rb — simplified
case @message_type
when '0' then first_dial                     # New session → Resume Check → API Lookup → Route to Module
when '1' then Menu::Manager.process(@params) # Continuing → read tracker → dispatch
when '2' then release                        # Gateway ending → clean Redis
end
```

**Logging:** Every request is logged with MSISDN, msg_type, and ussd_body.

**Error handling:** If any exception bubbles up, it catches it and returns a graceful `end_session("Internal system error")` instead of crashing.

**`extract_service_code` — how `ussd_body` becomes a service code:**

On `msg_type: '0'`, the gateway puts the raw dialled string into `ussd_body` (e.g. `*447*8115#`). `Service::Base` extracts the merchant service code from it before hitting the entity API:

```ruby
def extract_service_code
  body = @params[:ussd_body].to_s.gsub(/#/, '')  # "*447*8115#" → "*447*8115"
  body.include?('*') ? body.split('*').last : body # → "8115"
end
```

| Dialled | After strip `#` | Result |
|---------|----------------|--------|
| `*447#` | `*447` | `447` |
| `*447*8115#` | `*447*8115` | `8115` |
| `8115` | `8115` | `8115` |

If you need a different extraction strategy (e.g. first segment instead of last), override this method in a subclass of `Service::Base`.

---

### `controller/menu/`

**Purpose:** The state machine core. Three files, three responsibilities.

#### `menu/base.rb` — `Menu::Base`

The **shared superclass** for all pages and managers. Provides:

| Method | What it does |
|--------|-------------|
| `fetch_data` | Reads the Redis cache into `@data` |
| `store_data(hash)` | **Merges** (not replaces) new data into `@data` and writes back to Redis |
| `render_page(function:, page:, activity_type:)` | Saves the tracker and returns `display_message` |
| `continue(message)` | Wraps message in JSON with `msg_type: '1'` (keep session open). **Logs the display message.** |
| `end_session(message)` | Wraps message in JSON with `msg_type: '2'` (close session). **Logs the display message.** |
| `display_message` | **Abstract** — must be overridden by every page |

**`store_data` accumulates across turns.** Each call merges into the existing `@data` hash — it does not replace it. Data written in one turn is still there in all subsequent turns:

```ruby
# Turn 1 — user enters amount
store_data(amount: '50.00')
# @data => { tracker: {...}, amount: '50.00' }

# Turn 2 — user selects network
store_data(network: 'MTN')
# @data => { tracker: {...}, amount: '50.00', network: 'MTN' }

# Turn 3 — summary page reads both
@data[:amount]   # => '50.00'  ✓  still there
@data[:network]  # => 'MTN'    ✓  still there
```

This is the primary way pages pass data forward through a multi-step flow.

**Optional data threading:** All three base classes (`Menu::Base`, `Page::Base`, `Service::Base`) accept an optional `data` argument. When passed, the object uses it directly instead of fetching from Redis — useful for avoiding a round-trip when you already have `@data` in memory. Golden rule: **only pass `@data` to objects that won't call `store_data`**. If a service writes, omit the argument, then call `fetch_data` after it returns to resync your local state before passing it to the next page.

```ruby
# read-only service — safe to pass @data
items = Service::Base.new(@params, @data).entity_items

# writing service — let it fetch, then reload
Service::Gen.process(:name_lookup, @params)   # no data arg
fetch_data                                    # resync @data from Redis
Page::Gen::Summary.process(@params.merge(activity_type: REQUEST), @data)
```

**Display Logging:** Both `continue()` and `end_session()` log what the user sees on their phone:

```
[Display → CONTINUE] 233559904540: Auto Debit USSD\n1. Make Payment\n2. Contact Us
[Display → END] 233559904540: Thank you. Goodbye!
```

This makes debugging live sessions trivial — just `tail -f log/application.log`.

#### `menu/manager.rb` — `Menu::Manager`

The **switchboard**. On every `msg_type: '1'` request:

1. Reads `@data[:tracker]` from Redis.
2. Extracts the `function` key (e.g. `'make_payment'`).
3. **Extracts `activity_type`** from the tracker and merges it into `@params`.
4. Looks up the page class from the `MENU_MANAGER` hash.
5. Calls `PageClass.process(params)` (or `PageClass.process(params, data)` when the caller already holds the session hash).

> **Critical:** `Menu::Manager` must pass `activity_type` from the tracker into `@params`. Without this, `Page::Base#process` receives `nil` for `@activity_type` and crashes silently.

#### `menu/registry.rb` — `MENU_MANAGER`

The **central routing table**. This is the only file you edit when adding new pages.

```ruby
MENU_MANAGER = {
  MAINMENU             => Page::Gen::MainMenu,
  MAKE_PAYMENT         => Page::Gen::Payment,
  MAKE_PAYMENT_SUMMARY => Page::Gen::Summary,
  CONTACT_US           => Page::ContactUs
}.freeze

> [!IMPORTANT]
> **Every class** that defines a `process_response` method **must** have an entry in this hash. This ensures the state machine can correctly route user input back to the right page after a network trip.
```

---

### `controller/page/`

**Purpose:** The UI layer. Each file is one USSD screen.

#### `page/base.rb` — `Page::Base < Menu::Base`

Every page inherits from this. It provides the core `process` method:

```ruby
def process
  case @activity_type
  when REQUEST  then render_current_page   # Show the screen
  when RESPONSE then process_response      # Handle user input
  end
end
```

**Every page must implement:**

| Method | Purpose |
|--------|---------|
| `render_current_page` | Saves the tracker and returns the screen via `render_page(...)` — do NOT wrap in `continue()`; `render_page` calls it internally |
| `process_response` | Reads `@ussd_body`, routes to the next page or re-renders |
| `display_message` | Returns the text string to show on the phone — do NOT include `@message_prepend`; `render_page` prepends it automatically |

#### Shared pages (root level)

Pages that are shared across ALL modules live at the root of `controller/page/`:

- `contact_us.rb` — `Page::ContactUs` — accepts a `return_to:` param so any module can call it
- `resume_session.rb` — `Page::ResumeSession` — offers resume after network drop (see [Session Resume](#session-resume))

#### The `return_to` pattern for shared pages

`@params[:return_to]` is only present on the first REQUEST turn — it is gone on the next POST because the telco resets params each round trip. **Any shared page that needs to return somewhere must persist `return_to` into `@data` during `render_current_page`**, then read it back from `@data` during `process_response`.

```ruby
# WRONG — return_to is nil on process_response
def process_response
  return_fn = @params[:return_to] || MAINMENU   # always falls back to MAINMENU
end

# CORRECT — persist it on the REQUEST turn
def render_current_page
  store_data(contact_return_to: @params[:return_to]) if @params[:return_to]
  render_page(function: CONTACT_US, activity_type: RESPONSE)
end

def process_response
  return_fn = @data[:contact_return_to] || MAINMENU   # survives across turns
  MENU_MANAGER[return_fn]&.process(@params.merge(activity_type: REQUEST)) ||
    Page::Gen::MainMenu.process(@params.merge(activity_type: REQUEST))
end
```

This pattern applies to any shared page that needs to know where to send the user back to.

#### Module pages (subdirectories)

Pages specific to a module live in a subdirectory:

- `gen/main_menu.rb` — `Page::Gen::MainMenu`
- `gen/payment.rb` — `Page::Gen::Payment`
- `gen/summary.rb` — `Page::Gen::Summary`

#### Validation Feedback (`invalid_input` helper)

When the user enters invalid input, pages re-render with an error hint prepended to the screen. This is the **Agropay validation pattern**, simplified into a single helper inherited from `Page::Base`.

```ruby
def process_response
  case @ussd_body
  when '1' then next_page
  else
    invalid_input           # Defaults to "Invalid option"
    # invalid_input('amount') # "Invalid amount"
  end
end

def display_message
  "My Menu\n\n1. Option One\n\n#{BACK}. Back"
end
```

`@message_prepend` is empty on first render (so nothing shows). `invalid_input` sets it and `render_page` automatically prepends it — never include it inside `display_message`. The user sees:

```
Invalid option

My Menu

1. Option One

00. Back
```

---

### `controller/service/`

**Purpose:** Business logic and external API calls. Pages should never make HTTP calls directly — they delegate to services.

#### `service/base.rb` — `Service::Base < Menu::Base`

`Service::Base` inherits from `Menu::Base`, giving it full session access (`fetch_data`, `store_data`). It provides two built-in private methods called by `Dial::Manager` on every first dial:

| Method | What it does |
|--------|-------------|
| `retrieve_entity_info` | Calls `RETRIEVE_ENTITY_INFO` via `ExternalApi.get_request`, stores `entity_info` in the session cache, returns the data hash or `nil` on failure |
| `extract_service_code` | Strips telco-prefix noise from the dial string (e.g. `*447*8115#` → `8115`) |

**GEN fallback:** `Dial::Manager#first_dial` uses `entity_info&.dig(:module) || GEN` — if the API is unreachable or returns a non-200, the user still lands on the main menu. Wire up the real endpoint when the backend is ready.

```ruby
# Usage from a page:
Service::Gen.process(:make_payment, @params)

# The service class:
class Gen < Service::Base
  def make_payment
    data = { session_id: @session_id, msisdn: @mobile_number, amount: @data[:amount], src: 'USSD' }
    response = ExternalApi.post_request(MAKE_PAYMENT_API, data)

    if response && response[:resp_code] == '000'
      end_session("Payment submitted.\n#{THANK_YOU}")
    else
      end_session(response ? response[:resp_desc] : 'Service unavailable. Please try again.')
    end
  end
end
```

**Pattern:** `Service::Base.process(action, params, data = nil)` uses `send(action)` to call the named method. Errors are caught and logged automatically — the caller receives `nil` on any failure. Pass `data` only when the service is **read-only** and you want to skip a Redis round-trip. If the service calls `store_data` internally, omit `data` and call `fetch_data` in the caller afterward (see [Common Pitfalls](#common-pitfalls)).

---

## Constants Reference

| Constant | Value | Purpose |
|----------|-------|---------|
| `REQUEST` | `'request'` | Activity type: display a screen |
| `RESPONSE` | `'response'` | Activity type: process user input |
| `BACK` | `'00'` | Navigation: go back / exit at root |
| `NEXT` | `'01'` | Navigation: next page in paginated list |
| `PREV` | `'02'` | Navigation: previous page in paginated list |
| `CONFIRM` | `'1'` | Navigation: confirm on summary screens |
| `MAINMENU` | `'main_menu'` | Registry key for the root menu |
| `MAKE_PAYMENT` | `'make_payment'` | Registry key for the payment page |
| `MAKE_PAYMENT_SUMMARY` | `'make_payment_summary'` | Registry key for the payment summary |
| `CONTACT_US` | `'contact_us'` | Registry key for the contact page |
| `RESUME_SESSION` | `'resume_session'` | Registry key for the session resume page |
| `BASE_URL` | `ENV['BASE_URL'] \|\| 'http://localhost:3000/api/v1'` | Base URL for all API calls (override per project) |
| `RETRIEVE_ENTITY_INFO` | `'entity/info'` | API path — fetch entity/initiator profile on first dial |
| `MAKE_PAYMENT_API` | `'transaction/payment'` | API path — submit a payment |
| `COUNTRY_CODE` | `'GH'` | ISO country code |
| `APP_NAME` | `'USSD Template'` | Application name shown in menus (override per project) |
| `CURRENCY` | `'GHS'` | Currency symbol |
| `SUPPORT_PHONE` | `'+233 00 000 0000'` | Support phone number |
| `THANK_YOU` | `'Thank you for...'` | Standard end-of-session message |
| `NETWORKS` | Array of hashes | Mobile network definitions — `key` is used for MTN sleep check; `value` is the display label |

---

## Adding a New Module

Example: Adding a **Loan** module with 3 screens (Menu → Amount → Summary).

### Step 1 — Define Constants

In `util/constants.rb`:

```ruby
# Page Function Names
LOAN_MENU    = 'loan_menu'
LOAN_AMOUNT  = 'loan_amount'
LOAN_SUMMARY = 'loan_summary'
```

### Step 2 — Create Pages

Create the directory `controller/page/loan/` with three files:

**`controller/page/loan/menu.rb`**

```ruby
module Page
  module Loan
    class Menu < Page::Base
      def render_current_page
        continue(render_page(function: LOAN_MENU, activity_type: RESPONSE))
      end

      def process_response
        case @ussd_body
        when '1' then Page::Loan::Amount.process(@params.merge(activity_type: REQUEST))
        when BACK then Page::Gen::MainMenu.process(@params.merge(activity_type: REQUEST))
        else render_current_page
        end
      end

      def display_message
        "Loan Services\n\n1. Request Loan\n\n#{BACK}. Back"
      end
    end
  end
end
```

**`controller/page/loan/amount.rb`**

```ruby
module Page
  module Loan
    class Amount < Page::Base
      def render_current_page
        continue(render_page(function: LOAN_AMOUNT, activity_type: RESPONSE))
      end

      def process_response
        case @ussd_body
        when BACK then Page::Loan::Menu.process(@params.merge(activity_type: REQUEST))
        else
          if Util::Validation.valid_amount?(@ussd_body)
            store_data(loan_amount: @ussd_body)
            Page::Loan::Summary.process(@params.merge(activity_type: REQUEST))
          else
            render_current_page  # re-render on invalid input
          end
        end
      end

      def display_message
        "Enter Loan Amount (#{CURRENCY}):\n\n#{BACK}. Back"
      end
    end
  end
end
```

**`controller/page/loan/summary.rb`**

```ruby
module Page
  module Loan
    class Summary < Page::Base
      def render_current_page
        continue(render_page(function: LOAN_SUMMARY, activity_type: RESPONSE))
      end

      def process_response
        case @ussd_body
        when CONFIRM
          result = Service::LoanService.process(:request_loan, @params)
          end_session(result ? THANK_YOU : "Loan request failed. Try again.")
        when BACK then Page::Loan::Amount.process(@params.merge(activity_type: REQUEST))
        else render_current_page
        end
      end

      def display_message
        "Loan Summary\nAmount: #{CURRENCY} #{@data[:loan_amount]}\n\n#{CONFIRM}. Confirm\n#{BACK}. Back"
      end
    end
  end
end
```

### Step 3 — Register in the Router

In `controller/menu/registry.rb`:

```ruby
MENU_MANAGER = {
  MAINMENU             => Page::Gen::MainMenu,
  MAKE_PAYMENT         => Page::Gen::Payment,
  MAKE_PAYMENT_SUMMARY => Page::Gen::Summary,
  CONTACT_US           => Page::ContactUs,
  RESUME_SESSION       => Page::ResumeSession,
  # Loan Module
  LOAN_MENU            => Page::Loan::Menu,
  LOAN_AMOUNT          => Page::Loan::Amount,
  LOAN_SUMMARY         => Page::Loan::Summary
}.freeze
```

### Step 4 — Add Entry Point to Main Menu

In `controller/page/gen/main_menu.rb`:

```ruby
def process_response
  case @ussd_body
  when '1' then Page::Gen::Payment.process(@params.merge(activity_type: REQUEST))
  when '2' then Page::Loan::Menu.process(@params.merge(activity_type: REQUEST))   # NEW
  when '3' then Page::ContactUs.process(@params.merge(activity_type: REQUEST, return_to: MAINMENU))
  when BACK then end_session("Thank you. Goodbye!")
  else render_current_page
  end
end
```

### Step 5 — (Optional) Create a Service

In `controller/service/loan_service.rb`:

```ruby
module Service
  class LoanService < Service::Base
    def request_loan
      api = Util::Api::Base.new(ENV['LOAN_API_URL'])
      response = api.post('/loans', { amount: @params[:loan_amount], msisdn: @params[:msisdn] })
      response&.success?
    end
  end
end
```

**That's it.** No changes to `Dial::Manager`, `Menu::Manager`, `Menu::Base`, or `controller/init.rb`. The `Dir` glob in `init.rb` auto-discovers your new files.

---

## Adding a New Page to an Existing Module

1. Create the file in the module's directory (e.g. `controller/page/gen/receipt.rb`).
2. Add a constant in `util/constants.rb` (e.g. `RECEIPT = 'receipt'`).
3. Add one line in `controller/menu/registry.rb` (e.g. `RECEIPT => Page::Gen::Receipt`).
4. Wire it from the previous page's `process_response`.

> [!IMPORTANT]
> **Granular Registration Rule**: Never use the same `function` key for two different screen classes. Each unique Ruby class must have its own unique registry key.

---

## Pagination

For pages that display long lists (e.g. transaction history, product catalogs):

```ruby
class TransactionList < Page::Base
  include Pagination

  def render_current_page
    page_num = @data.dig(:tracker, :page).to_i
    paged = paginate(@data[:transactions], page: page_num)

    message = "Transactions:\n\n"
    paged.each_with_index { |t, i| message += "#{i + 1}. #{t[:description]} — #{CURRENCY} #{t[:amount]}\n" }
    message += nav_options(paged)
    message += "\n#{BACK}. Back"

    continue(render_page(function: TRANSACTIONS, page: paged.current_page))
  end

  def process_response
    case @ussd_body
    when NEXT, PREV
      new_page = resolve_page(@ussd_body, current: @data[:tracker][:page].to_i)
      self.class.process(@params.merge(activity_type: REQUEST, tracker: @data[:tracker].merge(page: new_page)))
    when BACK
      Page::Gen::MainMenu.process(@params.merge(activity_type: REQUEST))
    else
      # Handle item selection
    end
  end
end
```

---

## API Integration

External API calls follow this pattern:

```
Page → Service → Util::Api::Base → External API
```

**Never** make HTTP calls directly from a page. Always go through a `Service::*` class.

```ruby
# In a page's process_response (service owns end_session):
Service::Gen.process(:make_payment, @params)

# In service/gen.rb:
class Gen < Service::Base
  def make_payment
    data = { session_id: @session_id, msisdn: @mobile_number, amount: @data[:amount], src: 'USSD' }
    response = ExternalApi.post_request(MAKE_PAYMENT_API, data)

    if response && response[:resp_code] == '000'
      end_session("Payment submitted.\n#{THANK_YOU}")
    elsif response && response[:resp_code] == '085'
      end_session('Insufficient funds. Please top up and try again.')
    else
      end_session(response ? response[:resp_desc] : 'Service unavailable. Please try again.')
    end
  rescue StandardError => e
    LOGGER.error("[Service::Gen] #{e.message}")
    end_session('Failed to process payment. Please try again.')
  end
end
```

**Key rules:**
- Always use `ExternalApi.post_request` / `ExternalApi.get_request` — never instantiate `Util::Api::Base` directly in a service.
- `ExternalApi` returns a body that is already `with_indifferent_access` — do **not** chain `&.with_indifferent_access` on the result.
- The service calls `end_session` directly — the page just delegates: `Service::Gen.process(:make_payment, @params)`.
- Check `resp_code == '000'` for success, `'085'` for insufficient funds. Use `resp_desc` for all other backend errors.

---

## Configuration

All configuration lives in `util/constants.rb` — no environment variables or `.env` files are used. To change the API URL or Redis connection, edit the constants directly:

```ruby
BASE_URL   = 'http://your-api-host/api/v1'
REDIS_HOST = '127.0.0.1'
REDIS_PORT = 6379
REDIS_DB   = 0
```

---

## Boot Sequence & Load Order

The order in which files are loaded is **critical**. Base classes must load before subclasses.

### `app.rb` boot order:

```
1. sinatra, json, active_support          ← Gems
2. config/logger.rb                        ← LOGGER constant
3. config/redis.rb                         ← $redis global
4. util/**/*.rb                            ← Constants, Validation, Api
5. helpers/**/*.rb                         ← Pagination (mixins)
6. models/**/*.rb                          ← Cache
7. controller/init.rb                      ← Explicit load order (see below)
```

### `controller/init.rb` boot order:

```
1. session/base          ← Session::Base
2. session/manager       ← Session::Manager
3. menu/base             ← Menu::Base (depends on Cache, Session::Manager)
4. menu/manager          ← Menu::Manager (depends on Menu::Base)
5. page/base             ← Page::Base (depends on Menu::Base)
6. page/**/*.rb          ← All page files (depend on Page::Base)
7. menu/registry         ← MENU_MANAGER hash (depends on ALL page classes)
8. dial/manager          ← Dial::Manager (depends on Menu::Manager, page classes)
9. service/*.rb          ← Service classes
```

**Why is `menu/registry` loaded after pages?** Because `registry.rb` references page classes like `Page::Gen::MainMenu` — those classes must already be defined.

---

## Testing Locally

### Prerequisites

```bash
# Ensure Redis is running
redis-cli ping  # Should return PONG

# Install dependencies
bundle config set --local path 'vendor/bundle'
bundle install
```

### Start the server

```bash
rackup           # Uses Puma, listens on port 9292
# or
rackup -p 9000   # Custom port
```

### Test with curl

**First dial (new session):**

```bash
curl -X POST http://localhost:9292/ \
     -H "Content-Type: application/json" \
     -d '{"msisdn":"233559904540","msg_type":"0","ussd_body":"*8115#","session_id":"test001"}'
```

**Continue (select option 1):**

```bash
curl -X POST http://localhost:9292/ \
     -H "Content-Type: application/json" \
     -d '{"msisdn":"233559904540","msg_type":"1","ussd_body":"1","session_id":"test001"}'
```

**Release (end session):**

```bash
curl -X POST http://localhost:9292/ \
     -H "Content-Type: application/json" \
     -d '{"msisdn":"233559904540","msg_type":"2","ussd_body":"","session_id":"test001"}'
```

### Check Redis state

```bash
redis-cli HGETALL "test001-233559904540-cache"
```

---

## Deployment

See **[deployment.md](deployment.md)** for the full production guide — checklist, Puma, PM2, hot restart, log rotation, and Redis persistence.

---

## Session Resume

When a user's session drops (network issue, timeout, accidental hang-up), the app can offer to resume where they left off.

### How it works

1. **Every `Cache.store`** saves a pointer: `{msisdn}-last-session → session_id` (5-min TTL)
2. **On `first_dial`** (`msg_type: '0'`), `Dial::Manager` calls `Cache.find_previous_session(msisdn, current_session_id)`
3. **If a previous session exists** with a valid tracker → shows `Page::ResumeSession`
4. **User chooses:**
   - Press `1` → `Cache.migrate_session` copies old data into the new session → dispatches to the page they were on
   - Press `2` → goes to Main Menu as normal
5. **If 5 minutes pass** → Redis TTL expires, old session is gone, user gets Main Menu directly

### Implementation

```ruby
# In Dial::Manager#first_dial:
def first_dial
  previous = Cache.find_previous_session(@mobile_number, @params[:session_id])
  if previous
    Cache.store(@params.merge(cache: { previous_session: previous }.to_json))
    return Page::ResumeSession.process(@params.merge(activity_type: REQUEST))
  end

  # Retrieve entity info — falls back to GEN if the API is unreachable
  entity_info = Service::Base.process(:retrieve_entity_info, @params)
  module_code = entity_info&.dig(:module) || GEN
  route_to_module(module_code)
end
```

### What the user sees

```
You have an active session.

1. Continue where you left off
2. Start fresh

00. Exit
```

---

## Payment Processing Pattern

### Why Fire-and-End

USSD sessions have a hard telco timeout (typically 180 seconds total, much less per response). If your payment API call happens synchronously inside `process_response`, two things break:

1. **Timeout** — the API call takes longer than the remaining session budget → telco kills the session mid-flight.
2. **Blocking** — Puma's thread pool is pinned waiting for the HTTP response, reducing concurrency under load.

The solution is **fire-and-end**: close the USSD session immediately, then process the payment in a background thread. The user is notified of the result via SMS.

### The Pattern

```ruby
# In your summary page's process_response:
def process_payment
  # 1. End the USSD session immediately — never keep it open during API calls
  response = end_session("Payment received.\nYou will receive an SMS confirmation shortly.")

  # 2. Fire the payment in a background thread
  Thread.new do
    Service::PaymentService.process(:charge_customer, @params)
  rescue StandardError => e
    LOGGER.error("[PaymentThread] #{@params[:msisdn]} — #{e.message}")
    # Send SMS to user notifying them of failure (never raise — nobody catches it)
    Service::SmsService.process(:send_failure_sms, @params)
  end

  response
end
```

### Telco Payload Fields

Every POST from the gateway contains exactly 6 fields:

| Field | Mandatory | Description | Your response |
|-------|-----------|-------------|---------------|
| `session_id` | Yes | Unique session identifier — constant for the entire session | Echo unchanged |
| `msisdn` | Yes | Subscriber's phone number in international format (`233...`) | Echo unchanged |
| `msg_type` | Yes | `'0'` new / `'1'` continue / `'2'` end | **You set this** |
| `ussd_body` | Yes | Incoming: user's keypad input. Outgoing: your menu text | **You set this** |
| `nw_code` | Yes | Network code (`'01'` MTN / `'02'` Vodafone / `'03'` AirtelTigo) | Echo unchanged |
| `service_code` | Yes | The shortcode the user dialled (e.g. `'447'`) | Echo unchanged |

The echo rule is enforced automatically by `Session::Manager` — see the [controller/session/ section](#controllersession) above.

### The `nw_code` Field

The gateway sends `nw_code` to identify the subscriber's mobile network. It arrives in every POST body:

```json
{ "session_id": "abc123", "msisdn": "233559904540", "msg_type": "1", "ussd_body": "1", "nw_code": "01", "service_code": "447" }
```

The gateway uses numeric codes with a leading zero — `'01'`, `'02'`, `'03'`. These map to the `id` field in the `NETWORKS` constant:

```ruby
NETWORKS = [
  { id: '01', key: 'MTN', value: 'MTN' },
  { id: '02', key: 'VOD', value: 'Telecel' },
  { id: '03', key: 'AIR', value: 'AirtelTigo' }
].freeze
```

Always resolve the gateway code to the network `key` before using it — **never compare `nw_code` directly to `'MTN'`** since `'01' == 'MTN'` is always false:

```ruby
def resolve_network(nw_code)
  NETWORKS.find { |n| n[:id] == nw_code.to_s }&.fetch(:key)
end
```

For flows that let the user **select** their network from a menu, look up by the user's selection index:

```ruby
# In a network selection page's process_response:
network = NETWORKS[@ussd_body.to_i - 1]   # user presses 1 → { id: '01', key: 'MTN', ... }
store_data(network: network[:key])          # store 'MTN', 'VOD', or 'AIR'
```

For flows where the telco supplies it directly, resolve from `@params`:

```ruby
network_key = resolve_network(@params[:nw_code])   # '01' → 'MTN'
```

### MTN Timing Constraint

MTN holds its own USSD session open for a short window after your `end_session` response is sent. If the MoMo payment prompt arrives during that window, MTN's session conflicts with yours and the payment silently fails.

**Fix:** sleep a minimum of 2.5–3.5 seconds inside the thread before hitting the payment gateway — but **only for MTN**. Other networks (Telecel, AirtelTigo) do not have this constraint.

```ruby
network_key = @data[:network] || resolve_network(@params[:nw_code])

Thread.new do
  sleep 3 if network_key == 'MTN'   # Wait for MTN to release their session
  Service::PaymentService.process(:charge_customer, @params)
rescue StandardError => e
  LOGGER.error("[PaymentThread] #{@params[:msisdn]} — #{e.message}")
  Service::SmsService.process(:send_failure_sms, @params)
end
```

### Flow

```
User presses Confirm
       │
       ▼
process_payment runs
       │
       ├── end_session("Processing... SMS to follow")  → USSD closes (msg_type '2')
       │
       └── Thread.new fires
                 │
                 ├── network == 'MTN'? → sleep 3s
                 │
                 ▼
          API call to payment gateway
                 │
          ┌──────┴──────┐
          │ Success      │ Failure
          ▼              ▼
       Send SMS        Send SMS
     (confirmed)      (failed, retry info)
```

### Rules

| Rule | Reason |
|------|--------|
| Always call `end_session` **before** `Thread.new` | The return value of the page method must be the JSON response — the thread return value is discarded |
| Never `raise` inside the thread | Unjoined Ruby threads silently swallow exceptions — use `rescue` to log and send SMS |
| Always `rescue StandardError` in the thread | An unhandled exception in a thread kills that thread silently — the user never knows |
| MTN delay: 2.5–3.5 seconds | Hardcoded telco constraint — MTN session management window |
| Set Faraday timeout ≥ 10s | Payment gateways can be slow; the thread has no telco deadline, so give it headroom |

---

## Common Pitfalls

| Pitfall | Cause | Fix |
|---------|-------|-----|
| `NameError: uninitialized constant Page::Gen::MainMenu` | `menu/registry.rb` loaded before page files | Ensure `controller/init.rb` loads pages before registry |
| `404 on POST /` | `config.ru` doesn't load `app.rb` | `config.ru` should `require './app'` then `run Sinatra::Application` |
| Phone shows nothing / blank screen | Page returns raw string instead of JSON | Always use `continue(message)` or `end_session(message)` |
| User selection always goes to Main Menu | Page doesn't store its own function key in tracker | Override `render_current_page` with the correct `render_page(function: MY_KEY)` |
| Navigation crashes silently | `Menu::Manager` doesn't pass `activity_type` from tracker to `@params` | Always merge `activity_type: tracker[:activity_type]` in `Menu::Manager#process` |
| MTN payments silently fail | MoMo prompt arrives while MTN USSD session is still open | `sleep 3` inside the payment thread when `network == 'MTN'` |
| Payment exception disappears | `raise` inside unjoined thread — Ruby discards it | `rescue StandardError` in the thread, log + send failure SMS |
| Data written by a service disappears before the next page renders | `with_indifferent_access` creates a copy of `@data`; the service's `store_data` mutates its own copy and writes to Redis, but the caller's `@data` is still stale. Passing that stale hash to the next page causes its `store_data` (called inside `render_page`) to overwrite Redis and drop what the service wrote. | After any service call that writes data, call `fetch_data` in the caller to reload `@data` from Redis before passing it onward. Alternatively, don't pass `@data` to services that write — let them fetch independently. |
| `NoMethodError` on item selection | Assigning `selected_item: selected_item` where `selected_item` is treated as a method call, not a local variable | Always assign to a local variable first: `item = paged[index]`, then use `item` in the hash |
| "Extensions not built" on `bundle` | Ruby version changed, native gems need recompiling | `bundle config set --local path 'vendor/bundle'` then `bundle install` |
| Permission denied on `bundle install` | Trying to install to system gems | `bundle config set --local path 'vendor/bundle'` |
| BACK button goes to wrong page | Hardcoded `'0'` instead of constant `BACK` | Use `when BACK then ...` with `BACK = '00'` |

---

## Quick Reference Card

```
╔══════════════════════════════════════════════════════════╗
║                    LAYER CHEAT SHEET                     ║
╠══════════════════════════════════════════════════════════╣
║  config/       → LOGGER, $redis (load first)            ║
║  util/         → Standalone tools (no session context)   ║
║  helpers/      → Mixins for pages (session context)      ║
║  models/       → Redis persistence (Cache)               ║
║  session/      → JSON response formatting (never raw)    ║
║  dial/         → Entry point (msg_type routing)          ║
║  menu/base     → State management (fetch/store/render)   ║
║  menu/manager  → Switchboard (tracker → page dispatch)   ║
║  menu/registry → Routing table (add pages here)          ║
║  page/         → UI screens (REQUEST / RESPONSE)         ║
║  service/      → Business logic & API calls              ║
╠══════════════════════════════════════════════════════════╣
║  New module = constants + pages dir + registry entries   ║
║  New page   = file + constant + 1 line in registry      ║
╚══════════════════════════════════════════════════════════╝
```

---

*Last updated: April 2026 — yesuko*
