import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getTasks from '@salesforce/apex/TaskChecklistController.getTasks';
import completeTask from '@salesforce/apex/TaskChecklistController.completeTask';

function errorText(error) {
    if (!error) return '';
    if (error.body && error.body.message) return error.body.message;
    if (error.body && Array.isArray(error.body)) return error.body.map((e) => e.message).join(', ');
    return error.message || 'Something went wrong.';
}

export default class TaskChecklist extends LightningElement {
    @api recordId;
    tasks = [];
    includeClosed = false;
    error;

    connectedCallback() { this.load(); }
    toggleClosed(e) { this.includeClosed = e.target.checked; this.load(); }

    async load() {
        try {
            const data = await getTasks({ recordId: this.recordId, includeClosed: this.includeClosed });
            this.tasks = data.map((t) => ({ ...t, owner: t.Owner ? t.Owner.Name : '', due: t.ActivityDate || 'No due date', url: '/lightning/r/Task/' + t.Id + '/view' }));
            this.error = undefined;
        } catch (e) { this.error = errorText(e); }
    }

    get groups() {
        const today = new Date().toISOString().slice(0, 10);
        const week = new Date(Date.now() + 7 * 864e5).toISOString().slice(0, 10);
        const buckets = [
            { label: 'Overdue', test: (t) => !t.IsClosed && t.ActivityDate && t.ActivityDate < today },
            { label: 'Due this week', test: (t) => !t.IsClosed && t.ActivityDate && t.ActivityDate >= today && t.ActivityDate <= week },
            { label: 'Later', test: (t) => !t.IsClosed && (!t.ActivityDate || t.ActivityDate > week) },
            { label: 'Completed', test: (t) => t.IsClosed }
        ];
        return buckets.map((b) => ({ label: b.label, tasks: this.tasks.filter(b.test) })).filter((b) => b.tasks.length);
    }
    get empty() { return !this.error && this.tasks.length === 0; }

    async complete(e) {
        try {
            await completeTask({ taskId: e.target.dataset.id });
            this.dispatchEvent(new ShowToastEvent({ title: 'Task completed', variant: 'success' }));
            this.load();
        } catch (err) {
            this.dispatchEvent(new ShowToastEvent({ title: 'Could not complete task', message: errorText(err), variant: 'error' }));
        }
    }
}
