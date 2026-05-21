import { LightningElement, api, wire, track } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import getCountryInfo from
    '@salesforce/apex/CountryInfoService.getCountryInfo';
import LOCATION_FIELD from
    '@salesforce/schema/Job_Opening__c.Location__c';

export default class CountryInfoCard extends LightningElement {

    @api recordId;
    @track countryInfo = { found: false };
    @track isLoading = true;

    // get the location field from Job Opening
    @wire(getRecord, {
        recordId: '$recordId',
        fields: [LOCATION_FIELD]
    })
    wiredRecord({ data, error }) {
        if(data) {
            const location = getFieldValue(
                data, LOCATION_FIELD);
            if(location) {
                this.fetchCountryInfo(location);
            } else {
                this.isLoading = false;
                this.countryInfo = { found: false };
            }
        } else if(error) {
            this.isLoading = false;
            this.countryInfo = { found: false };
        }
    }

    fetchCountryInfo(location) {
        this.isLoading = true;
        getCountryInfo({ countryName: location })
            .then(result => {
                this.countryInfo = result;
                this.isLoading = false;
            })
            .catch(() => {
                this.countryInfo = { found: false };
                this.isLoading = false;
            });
    }

    get formattedPopulation() {
        if(!this.countryInfo?.population) return '—';
        return new Intl.NumberFormat().format(
            this.countryInfo.population);
    }
}
