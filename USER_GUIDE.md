# RTM View Shell — User Guide

## 1. Overview

**RTM View Shell** is a web application for creating and managing real-time monitoring dashboards for a contact centre. It allows you to:

- Create named dashboards and assign widget types to them
- Control which users and groups can view or edit each dashboard
- Manage user accounts and permission groups (administrators only)
- Browse the widget catalogue to explore available monitoring widgets

The application runs in a standard web browser — no installation is required on your workstation.

---

## 2. Signing In

### 2.1 Email and Password

1. Open the application URL in your browser (provided by your administrator)
2. Enter your **Email address** and **Password**
3. Click **Sign In**

If your credentials are correct, you will be redirected to the Dashboards page.

> **Account lockout:** After 5 consecutive failed login attempts, your account is locked for 15 minutes. Wait and try again, or contact your administrator.

### 2.2 Single Sign-On (SSO)

If your organisation has configured SSO (SAML 2.0 / OIDC):

1. Click **Sign in with SSO** on the login page
2. You will be redirected to your organisation's identity provider
3. After authentication, you are returned to the application automatically

> If you see "SSO is not configured yet", contact your administrator.

### 2.3 Two-Factor Authentication (2FA)

If 2FA is enabled for your account:

1. After entering your email and password, a 6-digit code is sent to your email address
2. Open the email and copy the code
3. Enter the code in the **Two-step verification** screen
4. Click **Verify**

The code is valid for **10 minutes** and can only be used once. If it expires, return to the login page and sign in again to receive a new code.

---

## 3. Application Layout

After signing in, the interface is divided into three areas:

| Area | Description |
|---|---|
| **Top bar** | Application name and Sign Out button |
| **Left sidebar** | Navigation menu — Dashboards, Widget Catalogue, Admin |
| **Main content** | Page content for the currently selected section |

---

## 4. Dashboards

### 4.1 Viewing Your Dashboards

Click **Dashboards** in the left sidebar. The page shows all dashboards you own or have permission to view, displayed as cards.

Each card shows:
- Dashboard **name**
- **Status** badge: Draft (grey), Active (green), or Archived (yellow)
- Date last **updated**
- **Edit** and **Delete** buttons

### 4.2 Creating a Dashboard

1. Click **+ New Dashboard** (top right of the Dashboards page)
2. Enter a **Name** (required, maximum 256 characters)
3. Click **Save**

The new dashboard is created with **Draft** status and appears in your dashboard list.

### 4.3 Editing a Dashboard

1. Click **Edit** on the dashboard card
2. Change the **Name** and/or **Status**:
   - **Draft** — work in progress, not yet active
   - **Active** — live and visible to permitted users
   - **Archived** — kept for reference, no longer active
3. Click **Save**

### 4.4 Deleting a Dashboard

1. Click **Delete** on the dashboard card
2. The dashboard is removed immediately

> **Note:** Deletion is permanent. There is no confirmation prompt — use with care.

---

## 5. Widget Catalogue

Click **Widget Catalogue** in the left sidebar to browse available widget types.

Widgets are organised by **category** (for example: Queues, Agents, Skills, Reports). Each category card shows:

- Category **name** and **description**
- List of **widget types** within that category, each with a name and description
- Number of widget types in the category

> **Note:** Widget rendering on dashboards is managed by a separate widget library. The catalogue is for reference — it shows what widgets are available to be added to a dashboard.

---

## 6. Administration

The **Admin** section is visible to users who have been granted administrative permissions. It contains two subsections: Users and Permission Groups.

### 6.1 User Management

Navigate to **Admin → Users**.

The page shows a table of all registered user accounts with:
- **Email** address
- **Display Name**
- **2FA** status (On / Off)
- **Status** (Active / Inactive)
- **Last Login** date and time

**Searching users**

Type in the search box (top of the page) to filter the list by email or display name. The list updates as you type.

**Activating / Deactivating a user**

- Click **Deactivate** to prevent a user from signing in. Their account is preserved but access is blocked.
- Click **Activate** to restore access for a previously deactivated user.

> Deactivated users cannot sign in and will receive "Invalid credentials" on the login page.

### 6.2 Permission Groups

Navigate to **Admin → Permission Groups**.

Permission groups control what menus and features each user can access. A user can belong to multiple groups; their effective permissions are the union of all their groups.

**Creating a group**

1. Click **+ New Group**
2. Enter a **Name** (required) and optional **Description**
3. In the **Menu Permissions** field, enter permission keys — one per line

   Example keys:
   ```
   dashboard.create
   admin.users
   admin.groups
   ```

4. Click **Save**

**Editing a group**

1. Click **Edit** next to the group
2. Modify the name, description, or permission keys
3. Click **Save**

**Deleting a group**

Click **Delete** next to the group. The group is removed immediately. Users who were members of the group lose the permissions it granted.

**Permission key format**

Keys follow the pattern `area.action`, for example:

| Key | Grants access to |
|---|---|
| `dashboard.create` | Creating new dashboards |
| `admin.users` | User Management page |
| `admin.groups` | Permission Groups page |
| `widgets.browse` | Widget Catalogue page |

---

## 7. Signing Out

Click **Sign Out** in the top bar. You are returned to the login page and your session is ended.

Your session also expires automatically after **8 hours** of inactivity.

---

## 8. Frequently Asked Questions

**I forgot my password — how do I reset it?**
Contact your administrator. Self-service password reset is not yet available.

**I did not receive my 2FA code.**
Check your spam/junk folder. If the code is still not there after 2 minutes, return to the login page and sign in again to request a new code.

**The page shows "Access Denied".**
You do not have permission to view that page. Contact your administrator to be added to an appropriate permission group.

**My account is locked.**
Accounts are locked for 15 minutes after 5 failed login attempts. Wait and try again. If the problem persists, contact your administrator.

**Can I use the application on a mobile device?**
Yes. The application is responsive and works in modern mobile browsers.
