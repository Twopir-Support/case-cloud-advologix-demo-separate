import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getPreview from '@salesforce/apex/BillingPreviewController.getPreview';
import updateDisposition from '@salesforce/apex/BillingPreviewController.updateDisposition';

function errorText(error) {
    if (!error) return '';
    if (error.body && error.body.message) return error.body.message;
    if (error.body && Array.isArray(error.body)) return error.body.map((e) => e.message).join(', ');
    return error.message || 'Something went wrong.';
}

const COLUMNS = [
    { label: 'Type', fieldName: 'kind', initialWidth: 80 },
    { label: 'Date', fieldName: 'lineDate', type: 'date-local', initialWidth: 110 },
    { label: 'Timekeeper / Category', fieldName: 'who' },
    { label: 'Hours', fieldName: 'hours', type: 'number', initialWidth: 80 },
    { label: 'Rate', fieldName: 'rate', type: 'currency', initialWidth: 100 },
    { label: 'Amount', fieldName: 'amount', type: 'currency', initialWidth: 110 },
    { label: 'Disposition', fieldName: 'disposition', initialWidth: 110 },
    { label: 'Status', fieldName: 'status', initialWidth: 110 },
    { label: 'Narrative', fieldName: 'narrative', wrapText: true }
];
const iso = (d) => d.toISOString().slice(0, 10);

export default class BillingPreview extends LightningElement {
    @api recordId;
    columns = COLUMNS;
    startDate;
    endDate = iso(new Date());
    dispositions = ['Bill', 'Hold', 'No Charge'];
    statuses = ['Unprocessed'];
    show = ['time', 'expense'];
    groups = [];
    selected = {};
    massDisposition = 'Bill';
    loading = false;
    error;

    dispositionOptions = ['Bill', 'Do Not Bill', 'Hold', 'No Charge'].map((v) => ({ label: v, value: v }));
    statusOptions = ['Unprocessed', 'Billed', 'Not Billed'].map((v) => ({ label: v, value: v }));
    showOptions = [{ label: 'Time', value: 'time' }, { label: 'Expenses', value: 'expense' }];

    connectedCallback() {
        const d = new Date();
        d.setMonth(d.getMonth() - 2);
        d.setDate(1);
        this.startDate = iso(d);
        this.load();
    }

    setStart(e) { this.startDate = e.target.value; }
    setEnd(e) { this.endDate = e.target.value; }
    setDispositions(e) { this.dispositions = e.detail.value; }
    setStatuses(e) { this.statuses = e.detail.value; }
    setShow(e) { this.show = e.detail.value; }
    setMass(e) { this.massDisposition = e.detail.value; }

    get noRows() { return !this.loading && this.groups.length === 0; }
    get selectedIds() { return Object.values(this.selected).flat(); }
    get noSelection() { return this.selectedIds.length === 0; }
    get grandTotal() { return this.groups.reduce((s, a) => s + (a.total || 0), 0); }

    async load() {
        this.loading = true;
        this.error = undefined;
        this.selected = {};
        try {
            const data = await getPreview({
                recordId: this.recordId, startDate: this.startDate, endDate: this.endDate,
                dispositions: this.dispositions, statuses: this.statuses,
                showTime: this.show.includes('time'), showExpense: this.show.includes('expense')
            });
            this.groups = data.map((a, i) => ({
                ...a, key: a.accountId || 'none' + i,
                matters: a.matters.map((m) => ({ ...m, url: '/lightning/r/Matter__c/' + m.matterId + '/view' }))
            }));
        } catch (e) {
            this.error = errorText(e);
            this.groups = [];
        } finally {
            this.loading = false;
        }
    }

    handleSelection(e) {
        const matter = e.target.dataset.matter;
        this.selected = { ...this.selected, [matter]: e.detail.selectedRows.map((r) => r.id) };
    }

    async massUpdate() {
        try {
            const n = await updateDisposition({ recordIds: this.selectedIds, disposition: this.massDisposition });
            this.dispatchEvent(new ShowToastEvent({ title: 'Disposition updated', message: n + ' record(s) set to ' + this.massDisposition + '. Billed records were skipped.', variant: 'success' }));
            this.load();
        } catch (e) {
            this.dispatchEvent(new ShowToastEvent({ title: 'Update failed', message: errorText(e), variant: 'error' }));
        }
    }

    exportCsv() {
        const esc = (v) => '"' + String(v === undefined || v === null ? '' : v).replace(/"/g, '""') + '"';
        const lines = [['Account', 'Matter Number', 'Matter', 'Type', 'Date', 'Timekeeper/Category', 'Hours', 'Rate', 'Amount', 'Disposition', 'Status', 'Narrative'].map(esc).join(',')];
        this.groups.forEach((a) => a.matters.forEach((m) => m.lines.forEach((l) => {
            lines.push([a.name, m.matterNumber, m.name, l.kind, l.lineDate, l.who, l.hours, l.rate, l.amount, l.disposition, l.status, l.narrative].map(esc).join(','));
        })));
        const link = document.createElement('a');
        link.href = 'data:text/csv;charset=utf-8,' + encodeURIComponent(lines.join('\n'));
        link.download = 'billing-preview.csv';
        link.click();
    }
}
