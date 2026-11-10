/** Budgets: detail roll-ups, locking, code-set consistency, templates; UTBMS code protection. */
public with sharing class BudgetService {
    public class BudgetException extends Exception {}

    // ---------- Budget
    public static void budgetBeforeUpdate(List<Budget__c> rows, Map<Id, Budget__c> oldMap) {
        for (Budget__c b : rows) {
            Budget__c o = oldMap.get(b.Id);
            if (o.Locked__c && b.Locked__c && (b.Fee_Budget__c != o.Fee_Budget__c || b.Expense_Budget__c != o.Expense_Budget__c)) {
                b.addError('This budget is locked. Unlock it before changing amounts.');
            }
        }
    }

    public static void budgetBeforeDelete(List<Budget__c> rows) {
        for (Budget__c b : rows) {
            if (b.Locked__c) {
                b.addError('A locked budget cannot be deleted.');
            }
        }
        LegalHoldGuard.blockDeletes(rows, 'Matter__c');
    }

    // ---------- Budget Detail
    public static void detailBefore(List<Budget_Detail__c> rows, Boolean isDelete) {
        Set<Id> budgetIds = new Set<Id>();
        Set<Id> codeIds = new Set<Id>();
        for (Budget_Detail__c d : rows) {
            budgetIds.add(d.Budget__c);
            if (d.UTBMS_Code__c != null) {
                codeIds.add(d.UTBMS_Code__c);
            }
        }
        Map<Id, Budget__c> budgets = new Map<Id, Budget__c>([
            SELECT Id, Locked__c, Matter__c, Matter__r.UTBMS_Code_Set__c, Budget_Template__r.UTBMS_Code_Set__c
            FROM Budget__c WHERE Id IN :budgetIds]);
        Map<Id, UTBMS_Code__c> codes = new Map<Id, UTBMS_Code__c>([SELECT Id, UTBMS_Code_Set__c FROM UTBMS_Code__c WHERE Id IN :codeIds]);
        Set<Id> held = new Set<Id>();
        if (isDelete) {
            Set<Id> matterIds = new Set<Id>();
            for (Budget__c b : budgets.values()) {
                matterIds.add(b.Matter__c);
            }
            held = LegalHoldGuard.mattersOnHold(matterIds);
        }
        for (Budget_Detail__c d : rows) {
            Budget__c b = budgets.get(d.Budget__c);
            if (b == null) {
                continue;
            }
            if (b.Locked__c) {
                d.addError('The parent budget is locked.');
            } else if (isDelete && held.contains(b.Matter__c)) {
                d.addError(LegalHoldGuard.HOLD_MESSAGE);
            } else if (!isDelete && d.UTBMS_Code__c != null) {
                Id expected = b.Budget_Template__r?.UTBMS_Code_Set__c != null ? b.Budget_Template__r.UTBMS_Code_Set__c : b.Matter__r?.UTBMS_Code_Set__c;
                Id actual = codes.get(d.UTBMS_Code__c)?.UTBMS_Code_Set__c;
                if (expected != null && actual != null && expected != actual) {
                    d.addError('The UTBMS code belongs to a different code set than this budget uses.');
                }
            }
        }
    }

    public static void detailAfter(List<Budget_Detail__c> rows) {
        Set<Id> budgetIds = new Set<Id>();
        for (Budget_Detail__c d : rows) {
            budgetIds.add(d.Budget__c);
        }
        rollUp(budgetIds);
    }

    public static void rollUp(Set<Id> budgetIds) {
        Map<Id, Budget__c> updates = new Map<Id, Budget__c>();
        for (Id i : budgetIds) {
            updates.put(i, new Budget__c(Id = i, Fee_Budget__c = 0, Expense_Budget__c = 0));
        }
        for (AggregateResult ar : [SELECT Budget__c b, SUM(Fee_Amount__c) fee, SUM(Expense_Amount__c) exp
                                   FROM Budget_Detail__c WHERE Budget__c IN :budgetIds GROUP BY Budget__c]) {
            Budget__c b = updates.get((Id) ar.get('b'));
            b.Fee_Budget__c = (Decimal) ar.get('fee');
            b.Expense_Budget__c = (Decimal) ar.get('exp');
        }
        update updates.values();
    }

    @AuraEnabled
    public static Integer applyTemplate(Id budgetId) {
        try {
            Budget__c b = [SELECT Id, Locked__c, Budget_Template__c, Matter__r.Type__c FROM Budget__c WHERE Id = :budgetId];
            if (b.Locked__c) {
                throw new BudgetException('This budget is locked.');
            }
            Id templateId = b.Budget_Template__c;
            if (templateId == null) {
                List<Budget_Template__c> ts = [SELECT Id FROM Budget_Template__c WHERE Active__c = true AND Type__c = :b.Matter__r.Type__c ORDER BY CreatedDate LIMIT 1];
                if (ts.isEmpty()) {
                    throw new BudgetException('There is no active budget template for matter type "' + b.Matter__r.Type__c + '".');
                }
                templateId = ts[0].Id;
            }
            List<Budget_Detail__c> details = new List<Budget_Detail__c>();
            for (Budget_Template_Detail__c t : [SELECT UTBMS_Code__c, Description__c, Hours__c, Fee_Amount__c, Expense_Amount__c
                                                FROM Budget_Template_Detail__c WHERE Budget_Template__c = :templateId ORDER BY Name]) {
                details.add(new Budget_Detail__c(Budget__c = budgetId, UTBMS_Code__c = t.UTBMS_Code__c, Description__c = t.Description__c,
                    Hours__c = t.Hours__c, Fee_Amount__c = t.Fee_Amount__c, Expense_Amount__c = t.Expense_Amount__c));
            }
            if (details.isEmpty()) {
                throw new BudgetException('The budget template has no details.');
            }
            update new Budget__c(Id = budgetId, Budget_Template__c = templateId);
            insert details;
            return details.size();
        } catch (Exception e) {
            AuraHandledException ex = new AuraHandledException(e.getMessage());
            ex.setMessage(e.getMessage());
            throw ex;
        }
    }

    // ---------- UTBMS
    public static void guardCodes(List<UTBMS_Code__c> rows) {
        for (UTBMS_Code__c c : rows) {
            if (c.Standard__c) {
                c.addError('Standard UTBMS codes cannot be deleted.');
            }
        }
    }

    public static void guardCodeSets(List<UTBMS_Code_Set__c> rows, Boolean isDelete) {
        if (isDelete) {
            for (UTBMS_Code_Set__c s : rows) {
                if (s.Standard__c) {
                    s.addError('Standard UTBMS code sets cannot be deleted.');
                }
            }
            return;
        }
        Integer defaults = 0;
        Set<Id> ids = new Set<Id>();
        for (UTBMS_Code_Set__c s : rows) {
            if (s.Default__c) {
                defaults++;
                if (s.Id != null) {
                    ids.add(s.Id);
                }
            }
        }
        if (defaults == 0) {
            return;
        }
        Integer existing = [SELECT COUNT() FROM UTBMS_Code_Set__c WHERE Default__c = true AND Id NOT IN :ids];
        if (defaults + existing > 1) {
            for (UTBMS_Code_Set__c s : rows) {
                if (s.Default__c) {
                    s.addError('Only one UTBMS code set can be the default.');
                }
            }
        }
    }
}
