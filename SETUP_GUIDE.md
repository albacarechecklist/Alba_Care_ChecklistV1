# Alba Care Daily Checklist — Full Installation Guide

This package is a cloud-connected **Progressive Web App (PWA)** designed for iPhone. It opens from Safari like a website and can be installed on the iPhone Home Screen, while all users share one secure Supabase database.

## 1. What you need

1. A GitHub account.
2. A Supabase project.
3. The files in this package.
4. Optional: a Resend account/API key if you want email notifications in addition to in-app notifications.
5. For deploying the two Edge Functions, install the Supabase CLI on a computer. Supabase can deploy functions through its API without Docker.

> **Security rule:** `config.js` may contain only the Supabase project URL and the **publishable** key. Never put a service-role/server secret or Resend API key in GitHub, `config.js`, or browser code.

---

## 2. Create the Supabase project

1. Sign in to Supabase and create a new project, for example **Alba Care Daily Checklist**.
2. Select the region nearest to Riyadh/your users where available.
3. Save the database password in your password manager.
4. Wait until the project status is ready.

### Get the two browser-safe values

In Supabase Dashboard go to **Project Settings → API / API Keys** and copy:

- **Project URL**, for example `https://xxxxxxxx.supabase.co`
- **Publishable key** (`sb_publishable_...`)

Open `config.js` and replace:

```js
SUPABASE_URL: 'YOUR_SUPABASE_URL',
SUPABASE_ANON_KEY: 'YOUR_SUPABASE_PUBLISHABLE_ANON_KEY'
```

with your actual URL and publishable key.

The publishable key is intentionally visible to the browser. Database security is enforced by Row Level Security (RLS).

---

## 3. Create the database structure

1. In Supabase open **SQL Editor**.
2. Click **New query**.
3. Open `supabase/schema.sql` from this package.
4. Copy the complete SQL file into the SQL Editor.
5. Click **Run**.
6. Confirm there are no errors.

This creates:

- `profiles`
- `user_permissions`
- `areas`
- `checklist_items`
- `area_assignments`
- `submissions`
- `responses`
- `notifications`
- `app_settings`
- RLS policies, helper functions and realtime publication settings.

The `responses` table is intentionally designed without Reading/Value and Initials fields. A non-compliant (`NC`) answer requires an Action Plan / Notes entry.

---

## 4. Import all Alba Care areas and checklist items

1. Still in **SQL Editor**, create another query.
2. Open `supabase/seed_checklists.sql`.
3. Copy all content into the query.
4. Click **Run**.
5. In **Table Editor → areas**, verify the clinic areas appear.
6. In **Table Editor → checklist_items**, verify the checklist rows appear.

The package combines the two CSSD source pages into a single CSSD app area. Pages 29–30 of the source document are the non-compliance/action log; the app replaces that paper log with structured NC responses and action plans stored automatically with each submission.

---

## 5. Create the first Administrator

The first administrator must be bootstrapped once through Supabase. After this, the in-app Admin Control Panel creates other users.

### 5.1 Create the Auth user

1. Go to **Authentication → Users**.
2. Click **Add user / Create user**.
3. Enter the administrator's email and a strong temporary password.
4. Create the user.

The database trigger will automatically create that user's `profiles` and `user_permissions` rows.

### 5.2 Promote the user to Admin

In **SQL Editor**, replace the email below and run:

```sql
update public.profiles
set role = 'admin', is_active = true
where email = 'YOUR_ADMIN_EMAIL@example.com';

update public.user_permissions
set
  can_submit = true,
  can_view_reports = true,
  can_export = true,
  can_manage_users = true,
  can_manage_areas = true
where user_id = (
  select id from public.profiles
  where email = 'YOUR_ADMIN_EMAIL@example.com'
);
```

You now have the first full administrator.

---

## 6. Configure password reset URLs

The final GitHub Pages URL will normally look like:

`https://YOUR-GITHUB-USERNAME.github.io/alba-care-checklist/`

After GitHub Pages is live, go to Supabase:

**Authentication → URL Configuration**

Set:

- **Site URL** = your exact production GitHub Pages URL
- **Redirect URLs** = add the same exact URL. You may also add a local test URL if you use one.

Use the exact production URL in production. This is necessary for password-reset emails to return the user to the app.

---

## 7. Deploy the Admin and Email Edge Functions

Two server-side functions are included:

- `admin-create-user` — lets an authenticated Alba Care admin create Supabase users safely.
- `notify-admin` — sends an email after a checklist submission when email notification is configured.

### 7.1 Install and sign in to Supabase CLI

From Terminal/Command Prompt:

```bash
supabase login
supabase projects list
```

Find the **project ref** of the Alba Care project, then from the app package directory run:

```bash
supabase link --project-ref YOUR_PROJECT_REF
```

### 7.2 Add the server-only secret

In Supabase Dashboard, obtain the project's legacy **service_role** key/server secret from the API Keys area. **Do not expose it publicly.** Store it only as an Edge Function secret named `SERVICE_ROLE_KEY`.

CLI method:

```bash
supabase secrets set SERVICE_ROLE_KEY="YOUR_SERVER_SECRET"
```

Or use **Edge Functions → Secrets** in the Supabase Dashboard.

### 7.3 Optional email notifications

If you want email notifications:

1. Create/verify your sending domain with an email provider such as Resend.
2. Obtain its API key.
3. Store it only in Supabase:

```bash
supabase secrets set RESEND_API_KEY="YOUR_RESEND_API_KEY"
```

4. Set the recipient email in Supabase SQL Editor:

```sql
update public.app_settings
set value = 'admin@albacare.example'
where key = 'admin_notification_email';
```

5. In `supabase/functions/notify-admin/index.ts`, replace the sample `from` address with your verified sender when moving to production.

If Resend is not configured, **in-app realtime notifications still work**; the function simply skips email.

### 7.4 Deploy the functions

From the project folder:

```bash
supabase functions deploy admin-create-user
supabase functions deploy notify-admin
```

Or deploy all functions:

```bash
supabase functions deploy
```

---

## 8. Upload the app to GitHub

### Simple browser method

1. Sign in to GitHub.
2. Create a repository, for example `alba-care-checklist`.
3. Open the repository.
4. Click **Add file → Upload files**.
5. Upload the **contents inside** this package folder — `index.html`, `app.js`, `styles.css`, `config.js`, `manifest.webmanifest`, `service-worker.js`, `assets/`, `data/`, `supabase/`, etc. The important point is that `index.html` must be at the repository root.
6. Commit the upload to the `main` branch.

### Git command method

```bash
git init
git add .
git commit -m "Initial Alba Care checklist app"
git branch -M main
git remote add origin https://github.com/YOUR-USERNAME/alba-care-checklist.git
git push -u origin main
```

---

## 9. Turn on GitHub Pages

In the GitHub repository:

1. Go to **Settings**.
2. Select **Pages**.
3. Under **Build and deployment**, choose **Deploy from a branch**.
4. Branch: `main`.
5. Folder: `/(root)`.
6. Save.
7. Wait for GitHub to publish the site.
8. Open the published HTTPS URL.

Return to Supabase **Authentication → URL Configuration** and ensure this exact URL is entered as the Site URL and Redirect URL.

---

## 10. First login and Admin Control Panel

1. Open the GitHub Pages URL on iPhone or desktop.
2. Log in using the administrator account created in Step 5.
3. Open **Admin**.
4. Create staff accounts.
5. For each user choose:
   - Name
   - Email
   - Temporary password
   - Role
   - Permissions
   - Assigned clinic areas
6. Save the user.

Recommended permission patterns:

| Role | Submit | Reports | Export | Manage Users | Manage Areas |
|---|---:|---:|---:|---:|---:|
| Admin | Yes | Yes | Yes | Yes | Yes |
| Quality | Optional | Yes | Yes | No | Optional |
| Head Nurse | Yes | Yes | Yes | No | Optional |
| Nurse | Yes | Optional | No | No | No |
| Receptionist | Yes for assigned areas | No | No | No | No |
| Operations | Optional | Yes | Yes | No | Optional |
| Medical Director | Optional | Yes | Yes | No | No |
| Viewer | No | As approved | No | No | No |

Only assign users to areas they are responsible for. The database RLS enforces those assignments for checklist submission.

---

## 11. Install on each iPhone

For each staff iPhone:

1. Open **Safari**.
2. Enter the GitHub Pages URL.
3. Log in once to verify access.
4. Tap the **Share** button.
5. Tap **Add to Home Screen**.
6. Confirm the app name, then tap **Add**.
7. Launch **Alba Care Checklist** from the Home Screen.

No App Store installation is required for this PWA. All phones use the same cloud database and the same URL.

---

## 12. How daily checklist entry works

1. User logs in.
2. Home page shows only the areas assigned to that user.
3. User opens an area.
4. Each item displays three large phone-friendly choices:
   - **C** = Compliant
   - **NC** = Non-Compliant
   - **N/A** = Not Applicable
5. When **NC** is chosen, **Action Plan / Notes is mandatory**.
6. Submit the area checklist.
7. Supabase stores the user, area, date/time, each item status and action plan.
8. Authorized roles receive a realtime in-app notification. Optional email is sent to the configured administrator.

---

## 13. Compliance calculation

The dashboard treats N/A as excluded from the compliance denominator:

`Compliance % = C / (C + NC) × 100`

The dashboard includes:

- Today
- Last 7 Days
- Overall
- Total submissions
- Compliant / Non-compliant / N/A counts
- Compliance percentage
- Status distribution chart
- Compliance by area chart
- Compliance trend chart

---

## 14. Export reports

Authorized users can:

- **Export CSV** for analysis in Excel.
- **Print / Save PDF** from the report view using the browser's print dialog.

Exports are permission-controlled through `can_export`.

---

## 15. Password management

### User knows current login
Open **Profile → Change Password** and set a new password.

### User forgot password
On the login page tap **Forgot password**, enter the registered email and use the password-reset email. The reset link returns to the GitHub Pages app if Supabase URL Configuration was completed correctly.

---

## 16. Important production/security checks

Before full staff rollout:

1. Confirm `config.js` contains only the project URL and publishable key.
2. Search the GitHub repository to ensure no service-role/server secret, database password or Resend key was committed.
3. Verify RLS is enabled on all operational tables.
4. Test with a nurse account that it cannot open Admin or modify unassigned areas.
5. Test with a receptionist account assigned only to Reception/Waiting/etc.
6. Test an NC entry and ensure Action Plan / Notes is required.
7. Test a password reset.
8. Test CSV/PDF export with an authorized role.
9. Test realtime notifications using two phones.
10. If email is enabled, confirm the administrator receives a submission email.
11. Use individual named accounts; do not share one nurse login between multiple people because auditability depends on the authenticated user ID.

---

## 17. Updating the checklist later

For small text/item changes, update the records in Supabase `areas` and `checklist_items`. For a complete replacement dataset, generate a new controlled seed migration rather than deleting production submissions.

For interface updates, edit the GitHub files and commit to `main`; GitHub Pages republishes the app. Existing Supabase data remains intact.

---

## 18. Troubleshooting

### Blank app / configuration message
Check `config.js` for the correct Supabase project URL and publishable key.

### Login works but no areas appear
The administrator must assign that user to one or more areas in Admin → Users/Assignments.

### Password reset opens the wrong page
Correct Supabase Authentication → URL Configuration and ensure the exact GitHub Pages URL is allowed.

### “Admin access required” while creating a user
Verify the current user's `profiles.role` is `admin` and `is_active=true`, and the `admin-create-user` function is deployed with `SERVICE_ROLE_KEY` configured.

### Email not received
Check `RESEND_API_KEY`, the `admin_notification_email` setting, the verified sender/domain and the `from` address in `notify-admin`.

### In-app notifications do not update instantly
Verify the schema was run fully and the `notifications` table is included in the Supabase realtime publication.

### A staff member can see something they should not see
Disable that user immediately in the Admin panel, then review role, permissions and area assignments. RLS policies are the security boundary; do not “fix” access by exposing secret keys to the client.

---

## 19. Recommended rollout sequence

1. Build Supabase database.
2. Seed all checklists.
3. Create first Admin.
4. Deploy Edge Functions.
5. Publish GitHub Pages.
6. Configure Auth URLs.
7. Test Admin + one Head Nurse + one Nurse + one Receptionist account.
8. Validate dashboard calculations and exports.
9. Configure email if required.
10. Add the PWA to all staff iPhones.
11. Create real users and area assignments.
12. Begin controlled go-live and retain the old paper form briefly only as contingency during validation.
