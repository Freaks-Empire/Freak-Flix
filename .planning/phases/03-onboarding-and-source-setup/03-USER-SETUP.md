# Phase 3: User Setup Required

**Generated:** 2026-03-01
**Phase:** 03-onboarding-and-source-setup
**Status:** Incomplete

Complete these items to validate OneDrive device-code onboarding in a real Microsoft tenant.

## Environment Variables

| Status | Variable | Source | Add to |
|--------|----------|--------|--------|
| [ ] | `GRAPH_CLIENT_ID` | Microsoft Entra app registration -> Application (client) ID | `.env` |
| [ ] | `GRAPH_TENANT_ID` | Microsoft Entra app registration -> Directory (tenant) ID | `.env` |

## Account Setup

- [ ] **Create or select a Microsoft Entra app registration for Freak-Flix**
  - URL: https://entra.microsoft.com/
  - Skip if: You already have an app registration used for Freak-Flix OneDrive sign-in.

## Dashboard Configuration

- [ ] **Enable public client flows for device code auth**
  - Location: Microsoft Entra -> App registrations -> Authentication
  - Set to: Enable public client flows = Yes
  - Notes: Required for non-browser device-code onboarding on desktop/mobile.

## Verification

After completing setup, verify with:

```bash
flutter run -d windows
```

Expected results:
- Onboarding source list shows OneDrive card.
- Starting OneDrive opens device-code dialog with a code and verification URL.
- Cancelling or letting the code expire returns to source list with OneDrive marked incomplete.

---

**Once all items complete:** Mark status as "Complete" at top of file.
