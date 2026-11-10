import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';
import run from '@salesforce/apex/ConflictSearchService.runForIntake';

// Headless quick action: Conflict Check
export default class ConflictCheck extends NavigationMixin(LightningElement) {
    @api recordId;
    busy = false;

    @api async invoke() {
        if (this.busy) {
            return;
        }
        this.busy = true;
        try {
            await run({ intakeId: this.recordId }).then(result => { const variant = result.conflictStatus === 'Clear' ? 'success' : 'warning'; this.toast('Conflict check: ' + result.conflictStatus, result.results + ' matching matter role(s) found. Review the results on the conflict check record.', variant); this.go(result.conflictCheckId, 'Conflict_Check__c'); });
        } catch (error) {
            const message = (error && error.body && error.body.message) || 'Something went wrong. Try again or contact your administrator.';
            this.toast('Conflict Check failed', message, 'error');
        } finally {
            this.busy = false;
        }
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    refresh() {
        notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
    }

    go(recordId, objectApiName) {
        this.refresh();
        if (!recordId) {
            return;
        }
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId, objectApiName, actionName: 'view' }
        });
    }
}
