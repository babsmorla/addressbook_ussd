# USSD Template

This is a standardized Ruby/Sinatra template for building high-performance USSD gateways for the Apps-N-Mobile ecosystem.

## 🚀 Quick Start (Plug and Play)

1. **Clone/Copy** this template into your new project folder.
2. **Install Dependencies**:
   ```bash
   bundle install
   ```
3. **Database Setup**:
   - Update `config/database.yml`
   - Run: `rake db:create db:migrate`
4. **Run the Application**:
   ```bash
   rackup -p 9000
   ```
5. **Simulate a Request (Start Message)**:
   ```bash
   curl -X POST http://localhost:9000/ \
        -H "Content-Type: application/json" \
        -d '{"msisdn": "233240000000", "msg_type": "0", "ussd_body": "*713#", "session_id": "888"}'
   ```

---

## 🏗 Directory Architecture

```text
/
├── app.rb              # Sinatra Entry Point
├── config.ru           # Rack Entry Point
├── CLAUDE.md           # Master Brain Bridge
├── controller/
│   ├── dial/
│   │   └── manager.rb  # State Discriminator (START/CONTINUE/RELEASE)
│   └── menu/
│       └── manager.rb  # Menu States (WELCOME/SELECTION/SUCCESS)
├── models/             # ActiveRecord Persistence (Sessions/Logs)
├── services/           # Business Logic (External API calls)
├── util/               # Universal Helpers (Logger, Constants)
└── spec/               # RSpec Integration Tests
```

---

## 🍰 The USSD Layer Cake (Architecture)

This template follows a strict 5-layer architecture for maintainability and scale:

| Layer | Folder | Responsibility | Example |
| :--- | :--- | :--- | :--- |
| **1. Entry** | `app.rb` | Sinatra entry point. | `post '/' ...` |
| **2. Dispatch** | `controller/dial/` | State Discriminator (0/1/2). | `Dial::Manager` |
| **3. Logic** | `controller/service/`| Business Logic & Formatting. | `EntityService` |
| **4. UI** | `controller/page/` | Screen string building. | `WelcomePage` |
| **5. External** | `util/api/` | External HTTP API calls. | `OrchardApiClient` |

### **The Request Flow**
1. **Telco** sends POST to `app.rb`.
2. **`Dial::Manager`** checks `msg_type`:
   - If `0`, calls `first_dial` -> `EntityService`.
   - If `1`, calls `continuous_dial` -> `Menu::Manager`.
3. **`Menu::Manager`** switches to requested **`Page`**.
4. **`Page`** calls **`Service`** to get data (e.g., `BalanceService`).
5. **`Service`** uses **`Api::Base`** to hit the backend.
6. **`Page`** returns the string to the Telco.

---

## 📜 Documentation Guide

When building a new USSD menu or service, you MUST maintain these documents:

### **1. State Lifecycle Checklist**
For every new menu option, verify:
- [ ] **State `msg_type: 0`**: Is the entry verification logic in `first_dial` in `dial/manager.rb`?
- [ ] **State `msg_type: 1`**: Does the `menu/manager.rb` handle the input correctly?
- [ ] **Session Continuity**: Are we properly keyed by `msisdn`?

### **2. Payload Register**
Maintain a `USSD_PAYLOADS.md` that chronicles the exact JSON required from the Telco (MTN, Telecel, AT). Example:
| Field | Type | Description |
| :--- | :--- | :--- |
| `msisdn` | String | International format phone number (e.g. 233...) |
| `msg_type` | String | 0=Start, 1=Continue, 2=End |
| `ussd_body` | String | The actual input code or selection value |

### **3. Performance Invariants**
- **Time to First Menu**: < 500ms
- **External API Timeout**: < 10s
- **Logging**: Every request MUST log MSISDN and Action.

---

## 🎨 Design Philosophy (Apps-N-Mobile Standards)
- **Simple**: Nested functions rather than global state.
- **Robust**: Wrap all `Faraday` calls in `begin/rescue` to prevent session crashes.
- **DRY**: Use centralized constants for menu strings.

---
*Last updated: April 2026 — yesuko*
