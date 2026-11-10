# Matter Management (Salesforce): CaseCloud-style demo

A Salesforce-native legal matter management app modelled on Mitratech CaseCloud (formerly AdvoLogix), built by Twopir as a separate demo.

| Document | What it covers |
|---|---|
| [`docs/CaseCloud-REA.html`](docs/CaseCloud-REA.html) | Reverse engineering analysis of CaseCloud: architecture, system design, object and API catalogue, records flow, automation map, user guide |
| [`docs/GAP_ANALYSIS.md`](docs/GAP_ANALYSIS.md) | What is built (waves 1 and 2) and what is still open |
| [`docs/DEPLOYMENT.md`](docs/DEPLOYMENT.md) | What was deployed to the SDO, test and coverage results, sample data counts |


A Salesforce-native legal matter management app built by Twopir. Object, field and Apex API names follow Mitratech CaseCloud (formerly AdvoLogix) as recorded in the CaseCloud reverse engineering analysis, without the `advpm__` namespace, which belongs to Mitratech's managed package and can't be used in another org. No Mitratech code is included; branding (CaseCloud, AdvoLogix, Mitratech) is not used in labels.

## Objects

| Label | API name | Notes |
|---|---|---|
| Intake | `Intake__c` | Name = Intake Request Name; Status Requested → In Progress → Submitted → Approved / Rejected; Type, Primary Account, Primary Contact, Start Date, Approver, Description |
| Conflict Check | `Conflict_Check__c` | Search Term, Description, Intake, Matter, Status |
| Conflict Check Result | `Conflict_Check_Result__c` | One matched party and its matter role |
| Matter | `Matter__c` | Matter Number, Type, Status, Primary Account, Primary Contact, Parent Matter, Legal Hold, Matter Age (in days), roll-ups |
| Participant | `Participant__c` | Matter, Role, Account, Contact, Staff (User), Other Name |
| Timekeeper | `Timekeeper__c` | Default and cost rates |
| Rate Group / Rate | `Rate_Group__c`, `Rate__c` | Default flag; matter rate → rate group → timekeeper default |
| Fee Arrangement / Matter Fee Arrangement | `Fee_Arrangement__c`, `Matter_Fee_Arrangement__c` | Source Fee Arrangement, Fee Arrangement Price, Discount %, Contingency %, Default for Fees / Expenses, Recurrence, NextBillDate, LastBillDate |
| Time | `Time__c` | Name "yyyy-mm-dd : Matter Name"; Time in Hours, Total Amount, Disposition, Status, Exported, Time Entry Lag |
| Expense | `Expense__c` | Disposition, Status, Source Fee Arrangement |
| Budget | `Budget__c` | Fee and expense budget, Active |
| UTBMS Code | `UTBMS_Code__c` | Task, activity and expense codes |
| Invoice / Invoice Line Item | `Invoice__c`, `Invoice_Line_Item__c` | Generated from unbilled time and expense |
| Matter Legal Hold Acknowledgement | `Matter_Legal_Hold_Acknowledgement__c` | Created when a matter goes on legal hold |
| Activity Plan Template / Item / Activity Plan | `Activity_Plan_Template__c`, `Activity_Plan_Template_Item__c`, `Activity_Plan__c` | Applied to a matter, account or contact; creates Tasks |

Matter Type is a global value set (`Matter_Type`) shared by Intake, Matter and Activity Plan Template.

## Apex API

| Class | Method | Same shape as CaseCloud |
|---|---|---|
| `ConflictSearchService` | `executeSearch(List<InputWrapper>)`: searchTerm, description, matterId, contextRecordId → body, status 'TRUE'/'FALSE'. Flow action "Initiate Conflict Check" | yes |
| `RatesService` | `copyRates(fromMatterId, fromRateGroupId, toMatterId, copyDefaultFlag)` → JSON success/result. Flow action "Copy Rates" | yes |
| `ActionPlansUtilitiesExternal` | `ApplyActionPlan(name, templateId, recordIds, objectApiName)` → JSON success/result. Flow action "Apply Activity Plan" | yes |
| `IntakeService` | Convert to Matter (quick action and Flow) | |
| `BillingService` | Generate Invoice, Void Invoice | |

Triggers: `MatterTrigger`, `TimeTrigger`, `ExpenseTrigger`, `ParticipantTrigger` (legal hold locks, participant auto-add from lookups, roll-ups, rate resolution, billed-record lock).

App **Matter Management**, permission set **Matter_Management_User**.

## Deploy

```bash
./scripts/deploy.sh
```

Uses the org alias `sdo` by default (`SF_ALIAS` to change, `SF_AUTH_URL` to log in, `SEED=0` to skip sample data).

## Sample data

Fictional records, loaded by `scripts/apex/seed-1-reference.apex` to `seed-5-casecloud-extras.apex`: 8 accounts, 8 contacts, 6 timekeepers, 2 rate groups, 11 rates, 5 fee arrangements, 14 UTBMS codes, 4 activity plan templates, 9 intakes (one deliberate conflict), 8 matters, 30 time entries, 11 expenses, 6 budgets, 5 invoices and a legal hold. `remove-sample-data.apex` removes them.

## Second wave (CaseCloud gap closure)

| Feature | What was added |
|---|---|
| Matter children | `Cross_Reference_Matter__c`, `Offer_and_Demand__c`, `Comment__c` (all blocked from deletion during legal hold) |
| Budgets | `Budget_Detail__c` (roll up to Budget and Matter), `Budget_Template__c` / `Budget_Template_Detail__c`, Apply Budget Template action, Remaining Budget and % remaining fields, Locked budgets |
| UTBMS | `UTBMS_Code_Set__c`, one default set, standard codes and sets can't be deleted, budget lines must match the matter's code set |
| Rates | One default rate per timekeeper + matter + rate group; rate groups, timekeepers and matters with default rates can't be deleted |
| Timekeepers | "Create Timekeeper" checkbox on User creates the Timekeeper |
| Activities | Log Time action on Matter; any Task or Event on a matter with Time in Hours creates or updates a Time record. Activity plan items can depend on other items; moving a task re-dates its dependents |
| Time | Exported time is locked until Exported is cleared |
| Record types | Participant (Account, Contact, User, Other: set automatically); Matter (General, Litigation, Personal Injury, Family Law, Transactional), chosen by Intake > Matter Record Type |
| Legal hold | Email notice to each custodian, Acknowledge action, `LegalHoldCallback` interface hook, files on held matters can't be deleted |
| Reporting | `Transaction__c` (estimates, actuals, billed) rebuilt nightly by `TransactionsBatch` or per matter with Refresh Transactions |
| Recurring fees | `Recurrence_Transaction__c` generated daily by `RecurrenceService` for monthly or quarterly retainers and fixed fees; billed on the next invoice |
| Status rules | `Matter_Status_Rule__mdt` custom metadata evaluated daily by `MatterStatusRuleBatch` (sample rule: close settled matters after 30 days) |
| Other | `Skill_Certification__c`, Focus Matters (`Focus_Matter__c` + Add to Focus Matters action), Intake Approval process, `Matter_Management_Settings__c` (per-trigger off switches, email and callback settings) |
| Screens | Matter record page with Timeline, Billing Preview and Settlement tabs and Task Checklist; Matter Management home page with Focus Matters, Date Calculator and pending approvals; Billing Preview, Batch Time, Batch Conflict Check and Legal Tools tabs |

Apex APIs added: `DateCalculationService.addDays / daysBetween` (Date Calculation API), Flow actions Generate Recurring Fees, Refresh All Transactions, Apply Matter Status Rules, Calculate Date.

Scheduled jobs (`scripts/apex/schedule-jobs.apex`): Transactions Refresh 00:00, Recurring Fees 00:30, Status Rules 01:00.

Deploy note: deploy once with `MM_SKIP_OVERRIDES=1 python3 scripts/generate_metadata.py` (pages must exist first), then regenerate without it and deploy again so the app uses the Matter record page and home page.

Object metadata is generated by `scripts/generate_metadata.py`; Lightning pages by `scripts/generate_pages.py`.
