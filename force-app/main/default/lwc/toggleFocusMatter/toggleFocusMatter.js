import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';
import run from '@salesforce/apex/FocusMatterService.toggle';

// Headless quick action: Add to Focus Matters
export default class ToggleFocusMatter extends NavigationMixin(LightningElement) {
    @api recordId;
    busy = false;

    @api async invoke() {
        if (this.busy) {
            return;
        }
        this.busy = true;
        try {
            await run({ matterId: this.recordId }).then(result => { this.toast(result ? 'Added to Focus Matters' : 'Removed from Focus Matters', result ? 'This matter now appears on your home page.' : 'This matter is no longer on your Focus Matters list.', 'success'); this.refresh(); });
        } catch (error) {
            const message = (error && error.body && error.body.message) || 'Something went wrong. Try again or contact your administrator.';
            this.toast('Add to Focus Matters failed', message, 'error');
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
