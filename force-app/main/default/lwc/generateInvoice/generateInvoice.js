import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';
import run from '@salesforce/apex/BillingService.generateInvoice';

// Headless quick action: Generate Invoice
export default class GenerateInvoice extends NavigationMixin(LightningElement) {
    @api recordId;
    busy = false;

    @api async invoke() {
        if (this.busy) {
            return;
        }
        this.busy = true;
        try {
            await run({ matterId: this.recordId }).then(result => { this.toast('Draft invoice created', 'Unbilled time and expenses up to today were added to a draft invoice.', 'success'); this.go(result, 'Invoice__c'); });
        } catch (error) {
            const message = (error && error.body && error.body.message) || 'Something went wrong. Try again or contact your administrator.';
            this.toast('Generate Invoice failed', message, 'error');
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
