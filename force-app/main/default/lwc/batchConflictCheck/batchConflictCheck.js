import { LightningElement } from 'lwc';
import runBatch from '@salesforce/apex/ConflictSearchService.runBatch';

function errorText(error) {
    if (!error) return '';
    if (error.body && error.body.message) return error.body.message;
    if (error.body && Array.isArray(error.body)) return error.body.map((e) => e.message).join(', ');
    return error.message || 'Something went wrong.';
}

export default class BatchConflictCheck extends LightningElement {
    terms = '';
    description = '';
    results = [];
    running = false;
    error;
    columns = [
        { label: 'Search term', fieldName: 'term' },
        { label: 'Result', fieldName: 'conflictStatus', cellAttributes: { class: { fieldName: 'cls' } } },
        { label: 'Matches', fieldName: 'results', type: 'number', initialWidth: 100 },
        { label: 'Conflict check', fieldName: 'url', type: 'url', typeAttributes: { label: { fieldName: 'linkLabel' }, target: '_self' } },
        { label: 'Message', fieldName: 'body', wrapText: true }
    ];
    setTerms(e) { this.terms = e.target.value; }
    setDescription(e) { this.description = e.target.value; }

    async run() {
        const list = this.terms.split('\n').map((t) => t.trim()).filter((t) => t);
        if (!list.length) { this.error = 'Enter at least one name.'; return; }
        if (list.length > 20) { this.error = 'Enter 20 names or fewer per batch.'; return; }
        this.running = true;
        this.error = undefined;
        try {
            const inputs = list.map((t) => ({ searchTerm: t, description: this.description }));
            const out = await runBatch({ inputs });
            this.results = out.map((r, i) => ({
                key: 'k' + i, term: list[i], conflictStatus: r.status === 'TRUE' ? r.conflictStatus : 'Error', results: r.results,
                url: r.conflictCheckId ? '/lightning/r/Conflict_Check__c/' + r.conflictCheckId + '/view' : null,
                linkLabel: r.conflictCheckId ? 'Open' : '', body: r.body,
                cls: r.conflictStatus === 'Clear' ? 'slds-text-color_success' : 'slds-text-color_error'
            }));
        } catch (e) {
            this.error = errorText(e);
        } finally {
            this.running = false;
        }
    }
}
