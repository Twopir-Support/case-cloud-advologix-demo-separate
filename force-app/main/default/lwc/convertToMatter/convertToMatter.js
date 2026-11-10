import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';
import run from '@salesforce/apex/IntakeService.convertIntake';

// Headless quick action: Convert to Matter
export default class ConvertToMatter extends NavigationMixin(LightningElement) {
    @api recordId;
    busy = false;

    @api async invoke() {
        if (this.busy) {
            return;
        }
        this.busy = true;
        try {
            await run({ intakeId: this.recordId }).then(result => { this.toast('Matter created', 'The intake was converted to a new matter.', 'success'); this.go(result, 'Matter__c'); });
        } catch (error) {
            const message = (error && error.body && error.body.message) || 'Something went wrong. Try again or contact your administrator.';
            this.toast('Convert to Matter failed', message, 'error');
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
