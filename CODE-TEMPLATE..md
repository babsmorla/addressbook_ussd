# USSD Code Template Footprint

This project is a Ruby/Sinatra USSD gateway template. It receives a telco-style JSON request, routes the user through menu pages, stores temporary session state in Redis, and returns JSON that tells the gateway whether to continue or end the session.

Use this file as the quick project footprint for building a similar app, especially a USSD address book where users can create, view, edit, and delete contacts.

## Stack

- Ruby + Sinatra: HTTP entry point in `app.rb`.
- Rack/Puma: booted through `config.ru`.
- Redis: short-lived USSD session cache in `models/cache.rb`.
- ActiveRecord/PostgreSQL: available through `sinatra-activerecord`, `pg`, and `rake`; add database models/migrations for permanent records.
- Faraday: external HTTP API wrapper in `util/api.rb`.
- RSpec/Rack::Test: request and helper tests in `spec/`.

## Runtime Contract

Incoming JSON: 

```json
{
  "msisdn": "233240000000",
  "msg_type": "0",
  "ussd_body": "*713#",
  "session_id": "abc123"
}
```

Important fields:

- `msisdn`: subscriber phone number.
- `msg_type`: `0` first dial, `1` continue, `2` release/end.
- `ussd_body`: short code on first dial, user input on later screens.
- `session_id`: telco/browser session id.

Outgoing JSON is built by `Session::Manager`:

- continue session: `msg_type: "1"`.
- end session: `msg_type: "2"`.
- display text is written into `ussd_body` and also consumed by the demo UI as `display_message`.

## Project Map

```text
app.rb                         # Sinatra entry point and demo phone UI bridge
config/logger.rb               # LOGGER
config/redis.rb                # $redis
util/constants.rb              # all global constants and menu keys
util/api.rb                    # Faraday client and ExternalApi shim
helpers/validations.rb         # validation helpers included into menus/pages
helpers/formatters.rb          # formatting helpers
helpers/pagination.rb          # long-list pagination helpers
models/cache.rb                # Redis session persistence
controller/init.rb             # controller load order
controller/dial/manager.rb     # routes msg_type 0/1/2
controller/session/manager.rb  # formats gateway responses
controller/menu/base.rb        # shared page/session methods
controller/menu/manager.rb     # dispatches to current tracked page
controller/menu/registry.rb    # maps function constants to Page classes
controller/page/base.rb        # REQUEST/RESPONSE page dispatcher
controller/page/**/*.rb        # screen classes
controller/service/**/*.rb     # business logic / API / DB actions
views/ui.erb                   # browser USSD simulator
spec/                          # tests
```

## Request Flow

1. `app.rb` receives `POST /`.
2. JSON requests go to `Dial::Manager.new(payload).process`.
3. `Dial::Manager` checks `msg_type`.
4. On `MSG_START`, it checks Redis for a resumable session, then routes to the main menu.
5. On `MSG_CONTINUE`, it calls `Menu::Manager.process`.
6. `Menu::Manager` reads Redis session data and dispatches to the current page from `MENU_MANAGER`.
7. A `Page::*` class either renders a screen or processes the user's latest input.
8. Page data is saved with `store_data(...)`.
9. Responses return through `continue(message)` or `end_session(message)`.

## State Machine Rules

Every page uses `activity_type`:

- `REQUEST`: render the page and store a tracker.
- `RESPONSE`: process the user's input from `@ussd_body`.

The tracker stored in Redis decides where the next input goes:

```ruby
tracker = {
  function: 'main_menu',
  page: '1',
  activity_type: 'response'
}
```

Use `render_page(function:, page: '1', activity_type: RESPONSE)` to save this tracker and show the message.

Use `store_data(key: value)` to keep temporary multi-step values such as `contact_name`, `contact_phone`, or `selected_contact_id`.

Redis session data expires after 5 minutes by default.

## Existing Page Pattern

A page normally looks like this:

```ruby
module Page
  module AddressBook
    class AddName < Page::Base
      def render_current_page
        render_page(function: ADD_CONTACT_NAME, activity_type: RESPONSE)
      end

      def process_response
        return invalid_input('name') if @ussd_body.to_s.strip.empty?

        store_data(contact_name: @ussd_body.strip)
        Page::AddressBook::AddPhone.process(@params.merge(activity_type: REQUEST))
      end

      def display_message
        "Add Contact\n\nEnter name:\n\n#{BACK}. Back"
      end
    end
  end
end
```

Required registration steps:

1. Add a constant in `util/constants.rb`, for example `ADD_CONTACT_NAME = 'add_contact_name'`.
2. Add the page to `controller/menu/registry.rb`, for example `ADD_CONTACT_NAME => Page::AddressBook::AddName`.
3. Add navigation to the previous page's `process_response`.

## How To Build A USSD Address Book

Recommended permanent data model:

```text
contacts
- id
- msisdn          # owner of the contact
- name
- phone_number
- email           # optional
- notes           # optional
- created_at
- updated_at
```

Suggested model:

```ruby
class Contact < ActiveRecord::Base
  validates :msisdn, :name, :phone_number, presence: true
end
```

Suggested constants:

```ruby
ADDRESSBOOK_MAIN       = 'addressbook_main'
ADD_CONTACT_NAME       = 'add_contact_name'
ADD_CONTACT_PHONE      = 'add_contact_phone'
ADD_CONTACT_SUMMARY    = 'add_contact_summary'
CONTACT_LIST           = 'contact_list'
CONTACT_DETAILS        = 'contact_details'
EDIT_CONTACT_MENU      = 'edit_contact_menu'
EDIT_CONTACT_NAME      = 'edit_contact_name'
EDIT_CONTACT_PHONE     = 'edit_contact_phone'
DELETE_CONTACT_CONFIRM = 'delete_contact_confirm'
```

Suggested menu:

```text
Address Book

1. Add Contact
2. View Contacts
3. Search Contact
00. Exit
```

## Address Book Flow

Add contact:

```text
MainMenu
-> AddName: collect name
-> AddPhone: collect phone number
-> AddSummary: show details before save
-> Confirm: Service::AddressBook.create_contact
-> End or return to main menu
```

View contact:

```text
MainMenu
-> ContactList: paginated list from DB
-> ContactDetails: show selected contact
-> EditContactMenu or DeleteContactConfirm
```

Edit before save:

```text
AddSummary
1. Save
2. Edit Name
3. Edit Phone
00. Cancel
```

Edit after save:

```text
ContactDetails
1. Edit
2. Delete
00. Back

EditContactMenu
1. Edit Name
2. Edit Phone
00. Back
```

Delete contact:

```text
ContactDetails
-> DeleteContactConfirm
1. Yes, delete
2. No, back
```

## Services For Address Book

Put database actions in `controller/service/address_book.rb`.

Suggested methods:

```ruby
module Service
  class AddressBook < Service::Base
    def create_contact
      Contact.create!(
        msisdn: @mobile_number,
        name: @data[:contact_name],
        phone_number: @data[:contact_phone]
      )
    end

    def list_contacts
      Contact.where(msisdn: @mobile_number).order(:name)
    end

    def find_contact
      Contact.where(msisdn: @mobile_number).find_by(id: @data[:selected_contact_id])
    end

    def update_contact(attrs)
      contact = find_contact
      contact&.update!(attrs)
      contact
    end

    def delete_contact
      find_contact&.destroy
    end
  end
end
```

Call services from pages like:

```ruby
Service::AddressBook.process(:create_contact, @params, @data)
```

## Pagination Pattern

Use `helpers/pagination.rb` for contact lists. Keep list screens short because USSD screens have limited space.

```ruby
contacts = Service::AddressBook.process(:list_contacts, @params, @data) || []
paged = paginate(contacts.to_a, page: @params.dig(:tracker, :page) || 1)
```

Display options should map visible numbers to records. Store the selected contact id:

```ruby
selected = paged[@ussd_body.to_i - 1]
store_data(selected_contact_id: selected.id)
Page::AddressBook::Details.process(@params.merge(activity_type: REQUEST))
```

Use `NEXT` (`01`) and `PREV` (`02`) for long lists, and `BACK` (`00`) to go back.

## Validation Rules

Reuse helpers in `helpers/validations.rb`:

- `valid_phone_number_format?(number)` for Ghana-style `0XXXXXXXXX` or `233XXXXXXXXX`.
- `valid_option?(input, options)` for menu choices.
- `invalid_input('phone number')` to re-render with an error prefix.

For address book, also add:

- required name.
- unique contact phone per `msisdn` if needed.
- max display length for names so list screens remain readable.

## Load Order Notes

`controller/init.rb` loads:

1. `controller/menu/base`
2. session classes
3. service base and services
4. all pages
5. menu files and registry
6. dial manager

Because registry loads after pages, every page class must exist before it is added to `MENU_MANAGER`.

## Agent Checklist For A New App

1. Update `APP_NAME`, support info, API constants, and module constants in `util/constants.rb`.
2. Add DB config/migrations/models for permanent entities.
3. Add service class for business actions.
4. Add page classes for each screen.
5. Add constants for every page function.
6. Register pages in `MENU_MANAGER`.
7. Route the start menu from `Dial::Manager#route_to_module`.
8. Use `store_data` for temporary multi-screen input.
9. Use DB records for permanent saved contacts.
10. Add tests for start menu, add flow, validation errors, edit flow, delete flow, and resume behavior.

## Local Commands

```bash
bundle install
bundle exec rackup -p 9000
bundle exec rspec
```

Example first dial:

```bash
curl -X POST http://localhost:9000/ \
  -H "Content-Type: application/json" \
  -d '{"msisdn":"233240000000","msg_type":"0","ussd_body":"*713#","session_id":"demo-1"}'
```

Example continue:

```bash
curl -X POST http://localhost:9000/ \
  -H "Content-Type: application/json" \
  -d '{"msisdn":"233240000000","msg_type":"1","ussd_body":"1","session_id":"demo-1"}'
```

## Design Principles

- Keep every screen small and direct.
- One page class should own one user decision or one data entry step.
- Store only temporary flow state in Redis.
- Store business data, such as contacts, in the database.
- Always provide `00. Back` or `00. Exit`.
- End sessions clearly after destructive actions or successful final actions.
- Keep constants centralized so routing keys do not drift.
- Let `Session::Manager` format all telco responses.
