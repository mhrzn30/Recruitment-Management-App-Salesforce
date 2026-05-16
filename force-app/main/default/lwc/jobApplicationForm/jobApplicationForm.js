import { LightningElement, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import getOpenJobOpenings from '@salesforce/apex/RecruitmentPublicController.getOpenJobOpenings';
import submitApplication from '@salesforce/apex/RecruitmentPublicController.submitApplication';

export default class JobApplicationForm extends LightningElement {
    jobOptions = [];
    loadError;
    isSubmitting = false;
    isSubmitted = false;
    currentStep = 1;
    preselectedJobId = '';

    jobOpeningId = '';
    firstName = '';
    lastName = '';
    email = '';
    phone = '';
    linkedInProfile = '';
    currentEmployer = '';
    currentJobTitle = '';
    yearsOfExperience = '';
    expectedSalary = '';
    noticePeriodDays = '';
    coverLetter = '';
    source = '';

    sourceOptions = [
        { label: 'LinkedIn', value: 'LinkedIn' },
        { label: 'Job Portal', value: 'Job Portal' },
        { label: 'Referral', value: 'Referral' },
        { label: 'Direct Application', value: 'Direct Application' },
        { label: 'Agency Database', value: 'Agency Database' },
        { label: 'Cold Outreach', value: 'Cold Outreach' },
        { label: 'Company Website', value: 'Company Website' },
        { label: 'Campus Recruitment', value: 'Campus Recruitment' }
    ];

    get hasJobs() {
        return this.jobOptions.length > 0;
    }

    get isStep1() {
        return this.currentStep === 1;
    }

    get isStep2() {
        return this.currentStep === 2;
    }

    get isStep3() {
        return this.currentStep === 3;
    }

    get step1Class() {
        return this.getStepClass(1);
    }

    get step2Class() {
        return this.getStepClass(2);
    }

    get step3Class() {
        return this.getStepClass(3);
    }

    get isNextDisabled() {
        if (this.isSubmitting) return true;
        if (this.isStep1) {
            return !this.firstName || !this.lastName || !this.email;
        }
        if (this.isStep2) {
            return !this.hasJobs || !this.jobOpeningId || !this.expectedSalary;
        }
        return true;
    }

    get isBackDisabled() {
        return this.isSubmitting || this.currentStep === 1;
    }

    get isSubmitDisabled() {
        return this.isSubmitting
            || !this.jobOpeningId
            || !this.firstName
            || !this.lastName
            || !this.email
            || !this.expectedSalary;
    }

    get selectedJobLabel() {
        const match = this.jobOptions.find(option => option.value === this.jobOpeningId);
        return match ? match.label : '—';
    }

    @wire(getOpenJobOpenings)
    wiredJobs({ data, error }) {
        if (data) {
            this.jobOptions = data.map(job => ({
                label: this.formatJobLabel(job),
                value: job.Id
            }));
            this.loadError = undefined;

            if (!this.jobOpeningId && this.preselectedJobId) {
                const match = this.jobOptions.find(
                    option => option.value === this.preselectedJobId
                );
                if (match) {
                    this.jobOpeningId = match.value;
                }
            }
        } else if (error) {
            this.jobOptions = [];
            this.loadError = error.body?.message || 'Unable to load job openings.';
        }
    }

    @wire(CurrentPageReference)
    wiredPageReference(pageRef) {
        const state = pageRef?.state;
        const jobId = state?.jobId || state?.c__jobId;
        if (!jobId) return;

        this.preselectedJobId = jobId;
        if (!this.jobOpeningId) {
            this.jobOpeningId = jobId;
        }
    }

    handleChange(event) {
        const field = event.target.dataset.field;
        const value = event.detail?.value ?? event.target.value;
        this[field] = value;
    }

    handleSubmit() {
        if (this.isSubmitDisabled || !this.isStep3) return;

        this.isSubmitting = true;
        submitApplication({
            jobOpeningId: this.jobOpeningId,
            firstName: this.firstName,
            lastName: this.lastName,
            email: this.email,
            phone: this.phone,
            linkedInProfile: this.linkedInProfile,
            currentEmployer: this.currentEmployer,
            currentJobTitle: this.currentJobTitle,
            yearsOfExperience: this.yearsOfExperience
                ? Number(this.yearsOfExperience)
                : null,
            expectedSalary: this.expectedSalary
                ? Number(this.expectedSalary)
                : null,
            noticePeriodDays: this.noticePeriodDays
                ? Number(this.noticePeriodDays)
                : null,
            coverLetter: this.coverLetter,
            source: this.source
        })
            .then(() => {
                this.isSubmitted = true;
            })
            .catch(error => {
                this.loadError = error.body?.message || 'Unable to submit application.';
            })
            .finally(() => {
                this.isSubmitting = false;
            });
    }

    handleReset() {
        this.currentStep = 1;
        this.jobOpeningId = '';
        this.firstName = '';
        this.lastName = '';
        this.email = '';
        this.phone = '';
        this.linkedInProfile = '';
        this.currentEmployer = '';
        this.currentJobTitle = '';
        this.yearsOfExperience = '';
        this.expectedSalary = '';
        this.noticePeriodDays = '';
        this.coverLetter = '';
        this.source = '';
        this.isSubmitted = false;
        this.loadError = undefined;
    }

    handleNext() {
        if (this.isNextDisabled || this.currentStep >= 3) return;
        this.currentStep += 1;
    }

    handleBack() {
        if (this.currentStep <= 1) return;
        this.currentStep -= 1;
    }

    getStepClass(stepNumber) {
        if (this.currentStep === stepNumber) {
            return 'step active';
        }
        if (this.currentStep > stepNumber) {
            return 'step complete';
        }
        return 'step';
    }

    formatJobLabel(job) {
        const title = job.Job_Title__c || job.Name;
        const detailParts = [job.Department__c, job.Location__c].filter(Boolean);
        if (detailParts.length === 0) {
            return title;
        }
        return `${title} — ${detailParts.join(' • ')}`;
    }
}
