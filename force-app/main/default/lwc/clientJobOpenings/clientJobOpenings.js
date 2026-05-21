import { LightningElement, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getMyJobOpenings from
    '@salesforce/apex/ClientPortalController.getMyJobOpenings';
import createJobOpening from
    '@salesforce/apex/ClientPortalController.createJobOpening';
import getRecruiters from
    '@salesforce/apex/ClientPortalController.getRecruiters';

const DEPARTMENT_OPTIONS = [
    { label: 'Engineering', value: 'Engineering' },
    { label: 'Product', value: 'Product' },
    { label: 'Design', value: 'Design' },
    { label: 'Marketing', value: 'Marketing' },
    { label: 'Sales', value: 'Sales' },
    { label: 'Operations', value: 'Operations' },
    { label: 'Finance', value: 'Finance' },
    { label: 'HR', value: 'HR' }
];

const EMPLOYMENT_OPTIONS = [
    { label: 'Full-Time', value: 'Full-Time' },
    { label: 'Part-Time', value: 'Part-Time' },
    { label: 'Contract', value: 'Contract' },
    { label: 'Internship', value: 'Internship' }
];

export default class ClientJobOpenings extends LightningElement {

    @track jobOpenings = [];
    @track showModal = false;
    @track isLoading = true;
    @track isSubmitting = false;
    @track error;

    wiredResult;
    recruiterOptions = [];

    form = {
        jobTitle: '',
        department: '',
        location: '',
        isRemote: false,
        employmentType: 'Full-Time',
        openingsCount: 1,
        deadline: '',
        minSalary: '',
        maxSalary: '',
        requiredExperienceYears: '',
        recruiterId: '',
        requiredSkills: '',
        jobDescription: ''
    };

    departmentOptions = DEPARTMENT_OPTIONS;
    employmentTypeOptions = EMPLOYMENT_OPTIONS;

    get hasOpenings() {
        return this.jobOpenings.length > 0;
    }

    @wire(getMyJobOpenings)
    wiredJobs(result) {
        this.wiredResult = result;
        const { data, error } = result;
        if (data) {
            this.jobOpenings = data.map(jo => ({
                ...jo,
                statusClass: jo.Status__c === 'Open'
                    ? 'status-badge status-open'
                    : 'status-badge status-closed',
                formattedDeadline: jo.Application_Deadline__c
                    ? new Date(jo.Application_Deadline__c)
                        .toLocaleDateString()
                    : 'N/A'
            }));
            this.isLoading = false;
            this.error = undefined;
        } else if (error) {
            this.error = error.body?.message ||
                'Error loading job openings';
            this.isLoading = false;
        }
    }

    @wire(getRecruiters)
    wiredRecruiters({ data, error }) {
        if (data) {
            this.recruiterOptions = [
                { label: 'Unassigned', value: '' },
                ...data.map(user => {
                    const nameParts = [user.FirstName, user.LastName]
                        .filter(Boolean);
                    const displayName = nameParts.length > 0
                        ? nameParts.join(' ')
                        : user.Name;
                    return {
                        label: displayName,
                        value: user.Id
                    };
                })
            ];
        } else if (error) {
            this.recruiterOptions = [
                { label: 'Unassigned', value: '' }
            ];
        }
    }

    handleNewOpening() {
        this.showModal = true;
    }

    closeModal() {
        this.showModal = false;
        this.resetForm();
    }

    handleFormChange(event) {
        const field = event.target.dataset.field;
        let value;
        if (event.target.type === 'checkbox') {
            value = event.target.checked;
        } else {
            value = event.detail?.value ?? event.target.value;
        }
        this.form = {
            ...this.form,
            [field]: value
        };
    }

    handleSubmit() {
        if (!this.form.jobTitle ||
           !this.form.department ||
           !this.form.employmentType ||
           !this.form.openingsCount ||
           !this.form.deadline) {
            this.showToast('Error',
                'Please fill in all required fields', 'error');
            return;
        }

        this.isSubmitting = true;

        createJobOpening({
            jobTitle: this.form.jobTitle,
            department: this.form.department,
            location: this.form.location,
            employmentType: this.form.employmentType,
            openingsCount: parseInt(this.form.openingsCount, 10),
            deadline: this.form.deadline,
            jobDescription: this.form.jobDescription,
            isRemote: !!this.form.isRemote,
            minSalary: this.form.minSalary !== ''
                ? Number(this.form.minSalary)
                : null,
            maxSalary: this.form.maxSalary !== ''
                ? Number(this.form.maxSalary)
                : null,
            requiredExperienceYears:
                this.form.requiredExperienceYears !== ''
                    ? Number(this.form.requiredExperienceYears)
                    : null,
            requiredSkills: this.form.requiredSkills,
            recruiterId: this.form.recruiterId || null
        })
        .then(() => {
            this.showToast('Success',
                'Job Opening posted successfully', 'success');
            this.closeModal();
            return refreshApex(this.wiredResult);
        })
        .catch(error => {
            this.showToast('Error',
                error.body?.message || 'Failed to post opening',
                'error');
        })
        .finally(() => {
            this.isSubmitting = false;
        });
    }

    resetForm() {
        this.form = {
            jobTitle: '',
            department: '',
            location: '',
            isRemote: false,
            employmentType: 'Full-Time',
            openingsCount: 1,
            deadline: '',
            minSalary: '',
            maxSalary: '',
            requiredExperienceYears: '',
            recruiterId: '',
            requiredSkills: '',
            jobDescription: ''
        };
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({ title, message, variant })
        );
    }
}
