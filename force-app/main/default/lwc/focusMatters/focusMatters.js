import { LightningElement } from 'lwc';
import getMyFocusMatters from '@salesforce/apex/FocusMatterService.getMyFocusMatters';

function errorText(error) {
    if (!error) return '';
    if (error.body && error.body.message) return error.body.message;
    if (error.body && Array.isArray(error.body)) return error.body.map((e) => e.message).join(', ');
    return error.message || 'Something went wrong.';
}

export default class FocusMatters extends LightningElement {
    rows = [];
    error;
    loaded = false;
    columns = [
        { label: 'Matter', fieldName: 'url', type: 'url', typeAttributes: { label: { fieldName: 'label' }, target: '_self' } },
        { label: 'Status', fieldName: 'status', initialWidth: 100 },
        { label: 'Stage', fieldName: 'stage', initialWidth: 120 },
        { label: 'Next task', fieldName: 'nextTask', wrapText: true, cellAttributes: { class: { fieldName: 'taskClass' } } },
        { label: 'Due', fieldName: 'nextTaskDate', type: 'date-local', initialWidth: 110 },
        { label: 'Unbilled', fieldName: 'unbilled', type: 'currency', initialWidth: 120 }
    ];
    connectedCallback() { this.load(); }
    async load() {
        try {
            const data = await getMyFocusMatters();
            this.rows = data.map((r) => ({ ...r, url: '/lightning/r/Matter__c/' + r.matterId + '/view', label: r.matterNumber + ' ' + r.name,
                taskClass: r.overdue ? 'slds-text-color_error' : '' }));
            this.error = undefined;
        } catch (e) { this.error = errorText(e); }
        this.loaded = true;
    }
    get empty() { return this.loaded && !this.error && this.rows.length === 0; }
}
