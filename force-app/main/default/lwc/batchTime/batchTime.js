import { LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getContext from '@salesforce/apex/BatchTimeController.getContext';
import saveEntries from '@salesforce/apex/BatchTimeController.saveEntries';

function errorText(error) {
    if (!error) return '';
    if (error.body && error.body.message) return error.body.message;
    if (error.body && Array.isArray(error.body)) return error.body.map((e) => e.message).join(', ');
    return error.message || 'Something went wrong.';
}

let seq = 0;
export default class BatchTime extends LightningElement {
    rows = [];
    timekeeperId;
    saving = false;
    error;

    async connectedCallback() {
        try {
            const ctx = await getContext();
            this.timekeeperId = ctx.timekeeperId;
        } catch (e) { this.error = errorText(e); }
        this.rows = [this.blank(), this.blank(), this.blank()];
    }
    blank() {
        seq += 1;
        return { key: 'r' + seq, matterId: null, timekeeperId: this.timekeeperId, entryDate: new Date().toISOString().slice(0, 10), hours: null, narrative: '' };
    }
    addRow() { this.rows = [...this.rows, this.blank()]; }
    removeRow(e) { this.rows = this.rows.filter((r) => r.key !== e.target.dataset.key); }
    update(key, field, value) { this.rows = this.rows.map((r) => (r.key === key ? { ...r, [field]: value } : r)); }
    edit(e) { this.update(e.target.dataset.key, e.target.dataset.field, e.target.value); }
    pick(e) { this.update(e.target.dataset.key, e.target.dataset.field, e.detail.recordId); }

    async save() {
        const filled = this.rows.filter((r) => r.matterId || r.hours);
        if (!filled.length) { this.error = 'Enter at least one row with a matter and hours.'; return; }
        this.saving = true;
        this.error = undefined;
        try {
            const payload = filled.map((r) => ({ matterId: r.matterId, timekeeperId: r.timekeeperId, entryDate: r.entryDate,
                hours: r.hours ? parseFloat(r.hours) : null, narrative: r.narrative }));
            const n = await saveEntries({ rowsJson: JSON.stringify(payload) });
            this.dispatchEvent(new ShowToastEvent({ title: 'Time saved', message: n + ' time entr' + (n === 1 ? 'y' : 'ies') + ' created.', variant: 'success' }));
            this.rows = [this.blank(), this.blank(), this.blank()];
        } catch (e) {
            this.error = errorText(e);
        } finally {
            this.saving = false;
        }
    }
}
