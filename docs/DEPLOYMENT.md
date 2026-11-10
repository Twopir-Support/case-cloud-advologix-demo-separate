# Deployment record

## Target
Salesforce SDO (demo org). Deployed with the Salesforce CLI in two passes (pages first, then app page assignments).

## Results at last deploy
- 31 custom objects, 274 custom fields, 1 hierarchy custom setting, 1 custom metadata type, 1 global value set
- 40 Apex classes, 19 triggers, 17 Lightning web components, 10 quick actions, 6 Lightning pages, 1 approval process
- 48 Apex tests passing; every class and trigger at 80% coverage or higher; 94% overall
- Permission set `Matter_Management_User` assigned to the admin user
- Scheduled jobs: Transactions Refresh (00:00), Recurring Fees (00:30), Status Rules (01:00)

## Sample data (fictional)
| Object | Records |
|---|---|
| Account / Contact | 8 / 8 (names end in "(Sample)") |
| Intake | 9 (6 converted, 1 potential conflict, 1 pending approval, 1 rejected) |
| Matter | 8 |
| Participant | 40 |
| Conflict Check / Result | 8 / 1 |
| Timekeeper / Rate Group / Rate | 6 / 2 / 11 |
| Fee Arrangement / Matter Fee Arrangement | 5 / 8 |
| Time / Expense | 32 / 11 |
| Budget / Budget Detail / Budget Template / Template Detail | 6 / 8 / 2 / 8 |
| Invoice / Invoice Line Item | 5 / 24 |
| Recurrence Transaction | 1 |
| Cross Reference / Offer and Demand / Comment | 4 / 6 / 6 |
| Skill & Certification / Focus Matter | 7 / 4 |
| UTBMS Code Set / UTBMS Code | 1 / 14 |
| Activity Plan Template / Item / Activity Plan | 4 / 20 / 6 |
| Matter Legal Hold Acknowledgement | 2 |
| Transaction | 80 |

## Notes
- Matter numbers start at MAT-00026 and invoice numbers at INV-00007 because test runs consumed earlier auto-numbers.
- Remove sample data with `scripts/apex/remove-sample-data.apex`.
