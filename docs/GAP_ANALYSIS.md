# CaseCloud gap analysis

Comparison of the Matter Management build against the Mitratech CaseCloud (formerly AdvoLogix) reverse engineering analysis (`docs/CaseCloud-REA.html`).

## Built and deployed

### Wave 1: core matter management

| Area | Objects / Apex |
|---|---|
| Intake and conversion | `Intake__c`, `IntakeService` (Convert to Matter) |
| Conflict checks | `Conflict_Check__c`, `Conflict_Check_Result__c`, `ConflictSearchService.executeSearch` |
| Matters and participants | `Matter__c`, `Participant__c`, participant auto-add from lookups |
| Activity plans | `Activity_Plan_Template__c`, `Activity_Plan_Template_Item__c`, `Activity_Plan__c`, `ActionPlansUtilitiesExternal.ApplyActionPlan` |
| Rates | `Timekeeper__c`, `Rate_Group__c`, `Rate__c`, `RatesService.copyRates`, rate resolution |
| Fee arrangements | `Fee_Arrangement__c`, `Matter_Fee_Arrangement__c` (hourly, fixed, contingency, capped, retainer) |
| Time and expense | `Time__c`, `Expense__c`, `UTBMS_Code__c`, dispositions, billed lock |
| Budgets | `Budget__c` |
| Billing | `Invoice__c`, `Invoice_Line_Item__c`, `BillingService` (generate / void) |
| Legal hold | `Matter_Legal_Hold_Acknowledgement__c`, delete and close guards |

### Wave 2: gap closure

| # | Feature |
|---|---|
| 1 | Cross Reference Matter, Offer and Demand, Comment (legal-hold protected) |
| 2 | Budget Details, Budget Templates, Apply Budget Template, Remaining Budget and % fields, Locked budgets |
| 3 | UTBMS Code Sets (single default, standard codes protected, budget code-set consistency) |
| 4 | Rate integrity: one default per timekeeper/matter/rate group; delete protection |
| 5 | Create Timekeeper checkbox on User |
| 6 | Log Time from Tasks and Events (Log Time action on Matter) |
| 7 | Activity plan dependencies and re-dating |
| 8 | Exported time lock |
| 9 | Participant record types (Account, Contact, User, Other) |
| 10 | Legal hold notices, Acknowledge action, `LegalHoldCallback` hook, file delete protection |
| 11 | Transactions reporting object, nightly batch, Refresh Transactions action |
| 12 | Skills & Certifications |
| 13 | Focus Matters |
| 14 | Matter Status Rules (custom metadata + nightly job) |
| 15 | Recurring fees (Recurrence Transactions) |
| 16 | Intake approval process |
| 17 | Matter record types chosen from the Intake |
| 18 | Matter Management Settings (per-trigger switches, email and callback settings) |
| 19 | Lightning components: Billing Preview, Matter Timeline, Date Calculator, Batch Time, Batch Conflict Check, Settlement Calculator, Task Checklist, Focus Matters; Matter record page, home page and four app tabs |

## Not built yet

| # | Feature | Notes |
|---|---|---|
| 20 | Reports and dashboards | Matter, WIP, budget vs actual, timekeeper reports and a dashboard |
| 21 | Spend Management (corporate legal) | Invoice rules (Pass/Flag/Reject), accruals, payments, cost centres, outside counsel portal |
| 22 | More visual components | Matter Calendar, Gantt, Kanban, relationship and participation maps, At a Glance, Mass Email, Enhanced Lists and Forms |
| 23 | Larger features | AdvoDoc document assembly, public intake form site, assignment rule sets, Einstein Next Best Actions, Experience Cloud sharing |
| 24 | Third-party integrations | Accounting Seed, iManage, NetDocuments, SharePoint, Google Drive, HotDocs, UniCourt, CalendarRules, CT SOP: each needs the vendor's product and account |
