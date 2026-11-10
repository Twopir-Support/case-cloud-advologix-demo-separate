import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';
import run from '@salesforce/apex/TransactionService.refreshMatter';

// Headless quick action: Refresh Transactions
export default class RefreshTransactions extends NavigationMixin(LightningElement) {
    @api recordId;
    busy = false;

    @api async invoke() {
        if (this.busy) {
            return;
        }
        this.busy = true;
        try {
            await run({ matterId: this.recordId }).then(result => { this.toast('Transactions refreshed', result + ' transaction row(s) rebuilt for this matter.', 'success'); this.refresh(); });
        } catch (error) {
            const message = (error && error.body && error.body.message) || 'Something went wrong. Try again or contact your administrator.';
            this.toast('Refresh Transactions failed', message, 'error');
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
