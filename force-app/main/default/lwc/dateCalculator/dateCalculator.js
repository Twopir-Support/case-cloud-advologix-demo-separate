import { LightningElement } from 'lwc';
import addDays from '@salesforce/apex/DateCalculationService.addDays';
import daysBetween from '@salesforce/apex/DateCalculationService.daysBetween';

function errorText(error) {
    if (!error) return '';
    if (error.body && error.body.message) return error.body.message;
    if (error.body && Array.isArray(error.body)) return error.body.map((e) => e.message).join(', ');
    return error.message || 'Something went wrong.';
}

export default class DateCalculator extends LightningElement {
    startDate = new Date().toISOString().slice(0, 10);
    endDate;
    days = 30;
    direction = 'after';
    business = false;
    result;
    between;
    error;
    directionOptions = [{ label: 'After', value: 'after' }, { label: 'Before', value: 'before' }];
    setStart(e) { this.startDate = e.target.value; }
    setEnd(e) { this.endDate = e.target.value; }
    setDays(e) { this.days = e.target.value; }
    setDirection(e) { this.direction = e.detail.value; }
    setBusiness(e) { this.business = e.target.checked; }
    async calculate() {
        try {
            const n = parseInt(this.days, 10) || 0;
            this.result = await addDays({ startDate: this.startDate, days: this.direction === 'before' ? -n : n, businessDaysOnly: this.business });
            this.error = undefined;
        } catch (e) { this.error = errorText(e); }
    }
    async count() {
        try {
            this.between = await daysBetween({ startDate: this.startDate, endDate: this.endDate });
            this.error = undefined;
        } catch (e) { this.error = errorText(e); }
    }
}
