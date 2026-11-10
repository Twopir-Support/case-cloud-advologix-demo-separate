/**
 * Date Calculator and Date Calculation API.
 * Business days skip weekends and any holidays on the org's default Business Hours.
 *   Date d = DateCalculationService.addDays(Date.today(), 30, true);
 *   Map<String, Integer> diff = DateCalculationService.daysBetween(start, finish);   // calendarDays, businessDays
 */
public with sharing class DateCalculationService {

    public class Request {
        @InvocableVariable(required=true label='Start Date') public Date startDate;
        @InvocableVariable(required=true label='Number of Days (negative = before)') public Integer days;
        @InvocableVariable(label='Business Days Only') public Boolean businessDaysOnly;
    }

    @InvocableMethod(label='Calculate Date' description='Adds calendar or business days to a date.' category='Matter Management')
    public static List<Date> calculateFromFlow(List<Request> requests) {
        List<Date> out = new List<Date>();
        for (Request r : requests) {
            out.add(addDays(r.startDate, r.days, r.businessDaysOnly == true));
        }
        return out;
    }

    @AuraEnabled
    public static Date addDays(Date startDate, Integer days, Boolean businessDaysOnly) {
        if (startDate == null || days == null) {
            return startDate;
        }
        if (businessDaysOnly != true) {
            return startDate.addDays(days);
        }
        Id bh = defaultBusinessHours();
        Integer step = days < 0 ? -1 : 1;
        Integer remaining = Math.abs(days);
        Date d = startDate;
        Integer guard = 0;
        while (remaining > 0 && guard < 5000) {
            d = d.addDays(step);
            if (isBusinessDay(d, bh)) {
                remaining--;
            }
            guard++;
        }
        return d;
    }

    @AuraEnabled
    public static Map<String, Integer> daysBetween(Date startDate, Date endDate) {
        Map<String, Integer> out = new Map<String, Integer>{ 'calendarDays' => 0, 'businessDays' => 0 };
        if (startDate == null || endDate == null) {
            return out;
        }
        out.put('calendarDays', startDate.daysBetween(endDate));
        Id bh = defaultBusinessHours();
        Integer step = endDate >= startDate ? 1 : -1;
        Integer count = 0;
        Date d = startDate;
        Integer guard = 0;
        while (d != endDate && guard < 5000) {
            d = d.addDays(step);
            if (isBusinessDay(d, bh)) {
                count += step;
            }
            guard++;
        }
        out.put('businessDays', count);
        return out;
    }

    @TestVisible
    private static Boolean isBusinessDay(Date d, Id businessHoursId) {
        String dow = Datetime.newInstance(d, Time.newInstance(12, 0, 0, 0)).format('u');
        if (dow == '6' || dow == '7') {
            return false;
        }
        return businessHoursId == null || BusinessHours.isWithin(businessHoursId, Datetime.newInstance(d, Time.newInstance(12, 0, 0, 0)));
    }

    private static Id defaultBusinessHours() {
        List<BusinessHours> bh = [SELECT Id FROM BusinessHours WHERE IsDefault = true LIMIT 1];
        return bh.isEmpty() ? null : bh[0].Id;
    }
}
