
# frozen_string_literal: true

# ── Session Activity Types ────────────────────────────────────────────────────
REQUEST  = 'request'
RESPONSE = 'response'

# ── Telco Message Types (msg_type) ────────────────────────────────────────────
MSG_START    = '0'
MSG_CONTINUE = '1'
MSG_RELEASE  = '2'

# ── Navigation Keys (keypad inputs) ──────────────────────────────────────────
BACK    = '00'   # Sub-pages: go back. Root menu: exit.
NEXT    = '01'   # Paginated lists: next page
PREV    = '02'   # Paginated lists: previous page
CONFIRM = '1'    # Summary pages: confirm and proceed

# ── Menu Function Keys (MENU_MANAGER registry keys) ──────────────────────────
MAINMENU             = 'main_menu'
MAKE_PAYMENT         = 'make_payment'
MAKE_PAYMENT_SUMMARY = 'make_payment_summary'
MAKE_PAYMENT_LAST    = 'make_payment_last'
ADD_CONTACT_NAME     = 'add_contact_name'
ADD_CONTACT_PHONE    = 'add_contact_phone'
ADD_CONTACT_SUMMARY  = 'add_contact_summary'
CONTACT_LIST         = 'contact_list'
CONTACT_DETAILS      = 'contact_details'
EDIT_CONTACT_MENU    = 'edit_contact_menu'
EDIT_CONTACT_NAME    = 'edit_contact_name'
EDIT_CONTACT_PHONE   = 'edit_contact_phone'
DELETE_CONTACT       = 'delete_contact'
CONTACT_US           = 'contact_us'
RESUME_SESSION       = 'resume_session'

# ── User Messages ─────────────────────────────────────────────────────────────
THANK_YOU = 'Thank you for using Address Book.'

# ── API ───────────────────────────────────────────────────────────────────────
BASE_URL             = 'http://localhost:3000/api/v1'
RETRIEVE_ENTITY_INFO = 'entity/info'
MAKE_PAYMENT_API     = 'transaction/payment'

# ── Redis ─────────────────────────────────────────────────────────────────────
REDIS_HOST = '127.0.0.1'
REDIS_PORT = 6379
REDIS_DB   = 0

# ── Module Codes (returned by API) ───────────────────────────────────────────
GEN = 'GEN'

# ── Mobile Networks (nw_code from telco payload) ─────────────────────────────
NETWORKS = [
  { id: '01', key: 'MTN', value: 'MTN' },
  { id: '02', key: 'VOD', value: 'Telecel' },
  { id: '03', key: 'AIR', value: 'AirtelTigo' }
].freeze

# ── App Info (OVERRIDE THESE PER PROJECT) ────────────────────────────────────
APP_NAME      = 'Address Book'
CURRENCY      = 'GHS'
COUNTRY_CODE  = 'GH'
SUPPORT_PHONE = '+233 00 000 0000'
SUPPORT_EMAIL = 'support@example.com'
