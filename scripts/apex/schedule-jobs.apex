// Schedules the nightly Matter Management jobs (safe to re-run: existing jobs with these names are replaced).
Map<String, Schedulable> jobs = new Map<String, Schedulable>{
    'Matter Management - Transactions Refresh' => new TransactionsBatch(),
    'Matter Management - Recurring Fees' => new RecurrenceService(),
    'Matter Management - Status Rules' => new MatterStatusRuleBatch()
};
Map<String, String> cron = new Map<String, String>{
    'Matter Management - Transactions Refresh' => '0 0 0 * * ?',
    'Matter Management - Recurring Fees' => '0 30 0 * * ?',
    'Matter Management - Status Rules' => '0 0 1 * * ?'
};
for (CronTrigger ct : [SELECT Id, CronJobDetail.Name FROM CronTrigger WHERE CronJobDetail.Name IN :jobs.keySet()]) System.abortJob(ct.Id);
for (String name : jobs.keySet()) System.schedule(name, cron.get(name), jobs.get(name));
System.debug('Scheduled ' + jobs.size() + ' jobs.');
