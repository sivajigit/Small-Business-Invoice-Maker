# Small Business Invoice Maker

A responsive invoice application using HTML, CSS, vanilla JavaScript, Express and Supabase PostgreSQL. Business users sign up, manage customers, create/edit/delete invoices, calculate tax, preview, print and track payment status. Administrators can view user and invoice statistics.

## Folder structure

```text
small-business-invoice-maker/
  frontend/index.html, styles.css, app.js
  backend/server.js, supabase.js, package.json, package-lock.json, .env.example, .gitignore
  backend/routes/auth.js, customers.js, invoices.js, admin.js
  backend/middleware/auth.js
  backend/utils/validate.js, seedAdmin.js
  database/schema.sql
  .gitignore
  README.md
```

## Prerequisites

- VS Code: https://code.visualstudio.com/
- Node.js LTS with npm: https://nodejs.org/
- Git: https://git-scm.com/downloads
- Supabase account: https://supabase.com/
- GitHub account: https://github.com/

Verify in Windows PowerShell: `node -v`, `npm -v`, `git --version`.

## Installation and setup (Windows)

1. Extract the ZIP and open the `small-business-invoice-maker` folder in VS Code (**File > Open Folder**). In VS Code select **Terminal > New Terminal**; it should open at the root folder.
2. Open Supabase, create a free project, wait for provisioning, then open **SQL Editor > New query**. Paste the entire `database/schema.sql` and click **Run**. Verify `users`, `customers`, `invoices`, and `invoice_items` appear in **Table Editor**.
3. In **Project Settings > API** (or API Keys), copy the Project URL and server-side `service_role` key. Never expose the key in frontend code.
4. In the VS Code terminal run `cd backend`, then `Copy-Item .env.example .env` (Windows PowerShell). On macOS/Linux use `cp .env.example .env`.
5. Edit `backend/.env`: set `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, and a fresh `JWT_SECRET`. Generate a secret using `node -e "console.log(require('crypto').randomBytes(48).toString('hex'))"`. Set `ADMIN_EMAIL=mrec@gmail.com` and `ADMIN_PASSWORD` to the desired admin password **only in this local ignored file**. Do not commit `.env`.
6. Run `npm install`. This installs the Express server, Supabase client, bcrypt password hashing, JWT signing, cookie parser, Helmet security headers, dotenv environment loading and rate limiter. A `package-lock.json` is generated or updated automatically.
7. Run `npm run seed:admin` to securely hash and create/update the admin account. The command should print `Administrator account created/updated`.
8. Run `npm start`. Expect `Invoice Maker: http://localhost:3000`. Open `http://localhost:3000` in your browser.
9. Use **Create an account** to register a business user, then sign in. Add a customer, create an invoice with line items, save, edit, preview, print, and delete it. Sign out and log in as admin to view admin statistics.

### Environment variables

| Variable | Purpose |
|---|---|
| `PORT` | Local HTTP port (default 3000) |
| `NODE_ENV` | `development` locally, `production` when HTTPS is configured |
| `SUPABASE_URL` | Supabase project URL |
| `SUPABASE_SERVICE_ROLE_KEY` | Server-only privileged database credential |
| `JWT_SECRET` | Random 32+ character JWT signing secret |
| `ADMIN_EMAIL` | Initial administrator email |
| `ADMIN_PASSWORD` | Local-only administrator seeding password |

`.env.example` is a safe template; `.env` contains private values and is ignored by Git.

## Architecture and data

Browser HTML/CSS/JS calls `/api` with `fetch`. Express authenticates users via signed, HTTP-only, SameSite=Lax cookies and checks ownership before calling Supabase PostgreSQL. Tables: `users` 1:N `customers`; `users` 1:N `invoices`; `customers` 1:N `invoices`; `invoices` 1:N `invoice_items`. SQL `save_invoice` runs item replacement and total calculation in a single PostgreSQL transaction. Invoice amounts are INR. The browser print dialog can save as PDF.

**Security:** Passwords are bcrypt-hashed, not stored in plaintext. Login endpoints are rate-limited. Helmet adds security headers. Browser JavaScript never sees the service-role key. All tables have RLS enabled without public policies; only the trusted server uses the service-role client, with explicit ownership and role checks. Cookies are `Secure` in production; deploy behind HTTPS. Avoid committing real customer data or credentials. Rotate any exposed keys immediately.

## API reference

All responses are JSON; errors have `{ "error": "message" }`. Except signup/signin/health, endpoints require a valid login cookie.

| Method | Path | Purpose / request | Success |
|---|---|---|---|
| GET | `/api/health` | Server health (public) | `{status:"ok"}` |
| POST | `/api/auth/signup` | `{name,email,password}` public | 201 message |
| POST | `/api/auth/signin` | `{email,password}` public | `{user}` + session cookie |
| POST | `/api/auth/logout` | End session | message |
| GET | `/api/auth/me` | Current user | `{user}` |
| GET | `/api/customers` | Own customers | `{customers}` |
| POST | `/api/customers` | `{name,email?,phone?,address?}` | 201 `{customer}` |
| DELETE | `/api/customers/:id` | Delete own unused customer | message |
| GET | `/api/invoices` | Own invoice list | `{invoices}` |
| GET | `/api/invoices/:id` | Own invoice details and items | `{invoice}` |
| POST | `/api/invoices` | Create invoice (body below) | 201 `{invoice_id}` |
| PUT | `/api/invoices/:id` | Update own invoice (same body) | `{invoice_id}` |
| DELETE | `/api/invoices/:id` | Delete own invoice | message |
| GET | `/api/admin/overview` | Admin only: users and totals | `{users,invoice_count,paid_total}` |

Invoice body example:

```json
{"number":"INV-001","customer_id":"CUSTOMER_UUID","issue_date":"2026-10-27","due_date":"2026-11-03","status":"draft","tax_percent":18,"items":[{"description":"Design service","quantity":2,"unit_price":500}]}
```

Replace `CUSTOMER_UUID` with a customer UUID returned by the API. Dates use `YYYY-MM-DD`. Errors: 400 invalid input, 401 not signed in, 403 admin-only, 404 not found, 409 duplicate invoice number/email or referenced customer, 429 excessive login attempts, 500 server/database failure.

## Testing checklist

- Register a user, sign in, reload: session persists until logout or 8-hour expiry.
- Duplicate email: 409. Invalid password (<10 characters) at signup: 400.
- Add a customer and verify it appears after reload.
- Save two items (2 × ₹500 and 1 × ₹200), 10% tax: subtotal ₹1200, tax ₹120, total ₹1320.
- Edit invoice: totals update; reload retains changes. Delete invoice: disappears.
- Search invoice number or customer: matching rows only.
- Print preview: only invoice prints; browser can save PDF.
- Try due date before issue date, zero quantity, negative price, invalid customer: 400.
- Delete customer referenced by an invoice: 409.
- Sign out then call `/api/invoices`: 401.
- Log in as another user: cannot see/edit/delete first user's invoices.
- Non-admin `/api/admin/overview`: 403. Admin account: overview works.
- Stop Supabase or misconfigure key: API returns generic error; details remain in server console.
- Resize browser to mobile width: forms stack and tables scroll horizontally.

## Troubleshooting

- `node is not recognized`: install Node.js LTS and reopen terminal.
- `Cannot find module`: run `npm install` from `backend`.
- `Set Supabase environment variables`: check `backend/.env` location and names.
- `JWT_SECRET must contain at least 32 characters`: generate a stronger secret.
- `relation does not exist` / missing RPC: run full `database/schema.sql` in Supabase SQL Editor.
- `Invalid API key`: check the Supabase URL and server-side key.
- `EADDRINUSE`: another server uses port 3000; change `PORT`.
- `Invalid email or password`: use signup or run `npm run seed:admin` after setting local admin password.
- Browser 404: use `http://localhost:3000`, not opening HTML via `file://`.

## GitHub upload

From root project directory:

```bash
git init
git status
git add .
git status
git commit -m "Build project"
git branch -M main
git remote add origin YOUR_GITHUB_REPOSITORY_URL
git push -u origin main
```

Create an empty GitHub repository first, then replace `YOUR_GITHUB_REPOSITORY_URL` with its actual clone URL. Check `git status` and `git ls-files` to confirm `.env` and `node_modules` are not tracked and `.env.example` is tracked. `.gitignore` does not erase secrets previously committed: rotate compromised credentials and clean repository history.

## Limitations and improvements

MVP supports single currency (INR), one tax percentage per invoice, no online payment gateway, no email sending, no password reset, no customer edit screen, and no admin user deletion. Possible improvements: business profiles/logo, downloadable PDF generation, invoice numbering rules, multiple tax types, pagination, and account recovery. No external paid API is required.
