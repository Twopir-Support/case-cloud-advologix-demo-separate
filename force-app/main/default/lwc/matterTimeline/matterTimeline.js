import { LightningElement, api, wire } from 'lwc';
import getTimeline from '@salesforce/apex/MatterTimelineController.getTimeline';

function errorText(error) {
    if (!error) return '';
    if (error.body && error.body.message) return error.body.message;
    if (error.body && Array.isArray(error.body)) return error.body.map((e) => e.message).join(', ');
    return error.message || 'Something went wrong.';
}

export default class MatterTimeline extends LightningElement {
    @api recordId;
    items = [];
    filter = 'All';
    error;

    @wire(getTimeline, { matterId: '$recordId' })
    wired({ data, error }) {
        if (data) {
            this.items = data.map((i, n) => ({ ...i, key: (i.recordId || '') + n, url: '/lightning/r/' + i.recordId + '/view' }));
            this.error = undefined;
        } else if (error) {
            this.error = errorText(error);
        }
    }

    get filterOptions() {
        const cats = ['All', ...new Set(this.items.map((i) => i.category))];
        return cats.map((c) => ({ label: c, value: c }));
    }
    get visible() { return this.filter === 'All' ? this.items : this.items.filter((i) => i.category === this.filter); }
    get empty() { return !this.error && this.items.length === 0; }
    setFilter(e) { this.filter = e.detail.value; }
}
