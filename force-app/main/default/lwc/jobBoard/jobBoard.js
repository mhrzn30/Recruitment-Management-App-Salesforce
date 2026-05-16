import { LightningElement, wire, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getOpenJobOpenings from '@salesforce/apex/RecruitmentPublicController.getOpenJobOpenings';

export default class JobBoard extends NavigationMixin(LightningElement) {
    @api applyPagePath = '/apply';
    jobs = [];
    loadError;

    get hasJobs() {
        return this.jobs.length > 0;
    }

    @wire(getOpenJobOpenings)
    wiredJobs({ data, error }) {
        if (data) {
            this.jobs = data.map(job => ({
                Id: job.Id,
                title: job.Job_Title__c || job.Name,
                department: job.Department__c,
                location: job.Location__c
            }));
            this.loadError = undefined;
        } else if (error) {
            this.jobs = [];
            this.loadError = error.body?.message || 'Unable to load job openings.';
        }
    }

    handleApply(event) {
        const jobId = event.currentTarget.dataset.id;
        if (!jobId) return;

        const url = this.buildApplyUrl(jobId);
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: { url }
        });
    }

    buildApplyUrl(jobId) {
        let path = this.applyPagePath || '/apply';
        if (!path.startsWith('/')) {
            path = `/${path}`;
        }

        const separator = path.includes('?') ? '&' : '?';
        return `${path}${separator}jobId=${encodeURIComponent(jobId)}`;
    }
}
