import { LightningElement, api, wire } from 'lwc';
import getDefaults from '@salesforce/apex/SettlementCalculatorController.getDefaults';

const n = (v) => (isNaN(parseFloat(v)) ? 0 : parseFloat(v));
const round = (v) => Math.round(v * 100) / 100;

export default class SettlementCalculator extends LightningElement {
    @api recordId;
    gross = 0;
    pct = 33.33;
    costs = 0;
    liens = 0;
    tax = 0;
    basis = 'gross';
    offerLabel;
    basisOptions = [{ label: 'Gross settlement', value: 'gross' }, { label: 'Net of costs', value: 'net' }];

    @wire(getDefaults, { matterId: '$recordId' })
    wired({ data }) {
        if (data) {
            this.gross = data.grossSettlement || 0;
            this.pct = data.contingencyPercent;
            this.costs = data.caseCosts || 0;
            this.offerLabel = data.offerLabel;
        }
    }
    edit(e) { this[e.target.dataset.f] = e.target.value; }
    editCombo(e) { this.basis = e.detail.value; }

    get costsNum() { return n(this.costs); }
    get liensNum() { return n(this.liens); }
    get fee() {
        const base = this.basis === 'net' ? n(this.gross) - n(this.costs) : n(this.gross);
        return round(Math.max(base, 0) * n(this.pct) / 100);
    }
    get taxAmount() { return round((n(this.gross) - this.fee - n(this.costs) - n(this.liens)) * n(this.tax) / 100); }
    get net() { return round(n(this.gross) - this.fee - n(this.costs) - n(this.liens) - Math.max(this.taxAmount, 0)); }
    get negative() { return this.net < 0; }
}
