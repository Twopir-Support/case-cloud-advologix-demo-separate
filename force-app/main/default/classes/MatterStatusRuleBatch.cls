/**
 * Matter Status Rules (custom metadata Matter_Status_Rule__mdt): moves matters to the rule's Target Status when
 * up to two conditions match (AND). Operators: equals, not equal to, less than, greater than, older than days,
 * is blank, is not blank. Matters on legal hold are never changed.
 * Schedule daily: System.schedule('Matter Management Status Rules', '0 0 1 * * ?', new MatterStatusRuleBatch());
 */
public with sharing class MatterStatusRuleBatch implements Schedulable {
    public class RuleException extends Exception {}

    @TestVisible private static List<Matter_Status_Rule__mdt> testRules;

    public void execute(SchedulableContext sc) {
        run();
    }

    @InvocableMethod(label='Apply Matter Status Rules' description='Evaluates the active Matter Status Rules now.' category='Matter Management')
    public static List<Integer> runFromFlow(List<String> ignored) {
        return new List<Integer>{ run() };
    }

    public static Integer run() {
        List<Matter_Status_Rule__mdt> rules = testRules != null ? testRules : [
            SELECT DeveloperName, Target_Status__c, Field_1__c, Operator_1__c, Value_1__c, Field_2__c, Operator_2__c, Value_2__c
            FROM Matter_Status_Rule__mdt WHERE Active__c = true ORDER BY Order__c];
        Integer changed = 0;
        for (Matter_Status_Rule__mdt r : rules) {
            Map<String, Object> binds = new Map<String, Object>{ 'target' => r.Target_Status__c };
            String whereClause = 'Status__c != :target AND Legal_Hold__c = false';
            whereClause += condition(r.Field_1__c, r.Operator_1__c, r.Value_1__c, binds, 'v1');
            whereClause += condition(r.Field_2__c, r.Operator_2__c, r.Value_2__c, binds, 'v2');
            List<Matter__c> matches = Database.queryWithBinds('SELECT Id FROM Matter__c WHERE ' + whereClause + ' LIMIT 2000', binds, AccessLevel.SYSTEM_MODE);
            for (Matter__c m : matches) {
                m.Status__c = r.Target_Status__c;
            }
            for (Database.SaveResult sr : Database.update(matches, false)) {
                if (sr.isSuccess()) {
                    changed++;
                }
            }
        }
        return changed;
    }

    @TestVisible
    private static String condition(String field, String op, String value, Map<String, Object> binds, String key) {
        if (String.isBlank(field) || String.isBlank(op)) {
            return '';
        }
        Schema.SObjectField f = Matter__c.SObjectType.getDescribe().fields.getMap().get(field.trim());
        if (f == null) {
            throw new RuleException('Matter field "' + field + '" does not exist.');
        }
        Schema.DescribeFieldResult d = f.getDescribe();
        String name = d.getName();
        Schema.DisplayType t = d.getType();
        if (op == 'is blank') {
            return ' AND ' + name + ' = null';
        }
        if (op == 'is not blank') {
            return ' AND ' + name + ' != null';
        }
        if (op == 'older than days') {
            Integer n = Integer.valueOf(value.trim());
            binds.put(key, t == Schema.DisplayType.DATE ? (Object) Date.today().addDays(-n) : (Object) System.now().addDays(-n));
            return ' AND ' + name + ' < :' + key;
        }
        Object typed;
        if (t == Schema.DisplayType.BOOLEAN) {
            typed = Boolean.valueOf(value);
        } else if (t == Schema.DisplayType.DATE) {
            typed = Date.valueOf(value);
        } else if (t == Schema.DisplayType.DATETIME) {
            typed = Datetime.valueOf(value);
        } else if (t == Schema.DisplayType.CURRENCY || t == Schema.DisplayType.DOUBLE || t == Schema.DisplayType.PERCENT || t == Schema.DisplayType.INTEGER) {
            typed = Decimal.valueOf(value);
        } else {
            typed = value;
        }
        binds.put(key, typed);
        Map<String, String> ops = new Map<String, String>{ 'equals' => '=', 'not equal to' => '!=', 'less than' => '<', 'greater than' => '>' };
        if (!ops.containsKey(op)) {
            throw new RuleException('Unknown operator "' + op + '".');
        }
        return ' AND ' + name + ' ' + ops.get(op) + ' :' + key;
    }
}
