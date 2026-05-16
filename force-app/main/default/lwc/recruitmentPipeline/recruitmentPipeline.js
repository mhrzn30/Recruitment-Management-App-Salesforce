import { LightningElement, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getApplications from '@salesforce/apex/RecruitmentPipelineController.getApplications';
import getLatestInterview from '@salesforce/apex/RecruitmentPipelineController.getLatestInterview';
import updateStage from '@salesforce/apex/RecruitmentPipelineController.updateStage';
import { refreshApex } from '@salesforce/apex';

// stage order — controls columns left to right
const STAGES = [
    { name: 'New',                 label: 'New',          color: '#6B7280' },
    { name: 'Screening',           label: 'Screening',    color: '#3B82F6' },
    { name: 'Shortlisted',         label: 'Shortlisted',  color: '#8B5CF6' },
    { name: 'Interview Scheduled', label: 'Interview Scheduled', color: '#F59E0B' },
    { name: 'Interview In Progress', label: 'Interview In Progress', color: '#F97316' },
    { name: 'Offer Pending',       label: 'Offer Pending',color: '#EF4444' },
    { name: 'Offer Extended',      label: 'Offer Extended',color: '#10B981'},
    { name: 'Hired',               label: 'Hired ✓',      color: '#059669' }
];

const FORWARD_BLOCKED_STAGES = new Set([
    'Shortlisted',
    'Interview Scheduled',
    'Interview In Progress'
]);

export default class RecruitmentPipeline extends NavigationMixin(LightningElement) {

    @track stages = [];
    @track isLoading = true;
    @track error;

    // summary counts
    totalActive = 0;
    offersPending = 0;
    totalHired = 0;

    // modal state
    showScheduleModal = false;
    showCompleteModal = false;
    activeAppId;
    activeInterviewId;

    // store wire result for refresh
    wiredResult;

    // wire to get applications
    @wire(getApplications)
    wiredHandler(result) {
        this.wiredResult = result;
        const { data, error } = result;
        if (data) {
            this.buildStages(data);
            this.isLoading = false;
            this.error = undefined;
        } else if (error) {
            this.error = error.body.message;
            this.isLoading = false;
        }
    }

    // build stage columns from flat list
    buildStages(applications) {
        // reset counts
        this.totalActive = 0;
        this.offersPending = 0;
        this.totalHired = 0;

        // group applications by stage
        const grouped = {};
        STAGES.forEach(s => grouped[s.name] = []);

        applications.forEach(app => {
            if (grouped[app.applicationStage] !== undefined) {
                grouped[app.applicationStage].push(
                    this.enrichApp(app)
                );
            }
            // counts
            if (app.applicationStage === 'Hired') {
                this.totalHired++;
            } else if (app.applicationStage === 'Offer Extended') {
                this.offersPending++;
                this.totalActive++;
            } else {
                this.totalActive++;
            }
        });

        // build stage objects for template
        this.stages = STAGES.map(s => {
            const stageKey = s.name.toLowerCase().replace(/\s+/g, '-');
            return {
                name: s.name,
                label: s.label,
                headerClass: `column-header header-${stageKey}`,
                applications: grouped[s.name],
                count: grouped[s.name].length,
                isEmpty: grouped[s.name].length === 0
            };
        });
    }

    // add computed properties to each application
    enrichApp(app) {
        const stageIndex = STAGES.findIndex(
            s => s.name === app.applicationStage
        );
        const stageName = app.applicationStage;
        const days = app.daysInCurrentStage || 0;

        // badge color based on days
        let badgeClass = 'badge-green';
        if (days > 7) badgeClass = 'badge-red';
        else if (days > 3) badgeClass = 'badge-amber';

        const showScheduleInterview = stageName === 'Shortlisted';
        const showStartInterview = stageName === 'Interview Scheduled';
        const showCompleteInterview = stageName === 'Interview In Progress';
        const showInterviewRound =
            stageName === 'Interview Scheduled'
            || stageName === 'Interview In Progress';
        const blockForward =
            showScheduleInterview || showStartInterview || showCompleteInterview;

        const firstName = app.candidateFirstName || '';
        const lastName = app.candidateLastName || '';
        const candidateName = `${firstName} ${lastName}`.trim();

        return {
            ...app,
            candidateName: candidateName || 'Unknown',
            accountName: app.accountName || '—',
            jobTitle: app.jobTitle || '—',
            badgeClass: `days-badge ${badgeClass}`,
            showScheduleInterview,
            showStartInterview,
            showCompleteInterview,
            showInterviewRound,
            interviewRoundLabel: app.latestInterviewRound || '—',
            canMoveBack: stageIndex > 0,
            canMoveForward: stageIndex < STAGES.length - 1 && !blockForward
        };
    }

    // handle move forward or back
    handleMove(event) {
        event.stopPropagation();

        const appId = event.currentTarget.dataset.id;
        const direction = event.currentTarget.dataset.direction;

        // find current stage index
        let currentIndex = -1;
        this.stages.forEach((stage, si) => {
            stage.applications.forEach(app => {
                if (app.Id === appId) currentIndex = si;
            });
        });

        if (currentIndex === -1) return;

        const currentStageName = STAGES[currentIndex].name;
        if (direction === 'forward'
            && FORWARD_BLOCKED_STAGES.has(currentStageName)) {
            this.showToast('Use Interview Actions',
                'Use the interview action button for this stage.', 'info');
            return;
        }

        const newIndex = direction === 'forward'
            ? currentIndex + 1
            : currentIndex - 1;

        if (newIndex < 0 || newIndex >= STAGES.length) return;

        const newStage = STAGES[newIndex].name;

        // call apex to update
        updateStage({ recordId: appId, newStage })
            .then(() => {
                this.showToast('Success',
                    `Moved to ${newStage}`, 'success');
                // refresh data using wiredResult
                return refreshApex(this.wiredResult);
            })
            .catch(error => {
                this.showToast('Error',
                    error.body.message, 'error');
            });
    }

    handleCardClick(event) {
        const recordId = event.currentTarget.dataset.id;
        if (!recordId) return;

        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId,
                objectApiName: 'Job_Application__c',
                actionName: 'view'
            }
        });
    }

    handleScheduleInterview(event) {
        event.stopPropagation();
        this.activeAppId = event.currentTarget.dataset.id;
        this.showScheduleModal = true;
    }

    handleStartInterview(event) {
        event.stopPropagation();
        const appId = event.currentTarget.dataset.id;
        updateStage({ recordId: appId, newStage: 'Interview In Progress' })
            .then(() => {
                this.showToast('Success',
                    'Moved to Interview In Progress', 'success');
                return refreshApex(this.wiredResult);
            })
            .catch(error => {
                this.showToast('Error',
                    error.body.message, 'error');
            });
    }

    handleCompleteInterview(event) {
        event.stopPropagation();
        const appId = event.currentTarget.dataset.id;
        this.activeAppId = appId;
        getLatestInterview({ appId })
            .then(interviewId => {
                if (!interviewId) {
                    this.showToast('No Interview Found',
                        'Please create an interview first', 'warning');
                    return;
                }
                this.activeInterviewId = interviewId;
                this.showCompleteModal = true;
            })
            .catch(() => {
                this.showToast('Error',
                    'Could not find interview record', 'error');
            });
    }

    handleScheduleSubmit(event) {
        event.preventDefault();
        const fields = event.detail.fields;
        fields.Job_Application__c = this.activeAppId;
        if (!fields.Status__c) {
            fields.Status__c = 'Scheduled';
        }
        if (!fields.Interview_Round__c) {
            fields.Interview_Round__c = 'Round 1';
        }
        if (fields.Mode__c === 'Video Call' && !fields.Meeting_Link__c) {
            fields.Meeting_Link__c = 'https://meet.google.com/new';
        }
        this.template
            .querySelector('lightning-record-edit-form[data-form="schedule"]')
            .submit(fields);
    }

    handleScheduleSuccess() {
        const appId = this.activeAppId;
        this.closeScheduleModal();
        this.showToast('Success',
            'Interview scheduled', 'success');
        updateStage({ recordId: appId, newStage: 'Interview Scheduled' })
            .then(() => refreshApex(this.wiredResult))
            .catch(error => {
                this.showToast('Error',
                    error.body.message, 'error');
            });
    }

    handleCompleteSubmit(event) {
        event.preventDefault();
        const fields = event.detail.fields;
        fields.Feedback_Submitted__c = true;
        this.template
            .querySelector('lightning-record-edit-form[data-form="complete"]')
            .submit(fields);
    }

    handleCompleteSuccess() {
        this.closeCompleteModal();
        this.showToast('Success',
            'Interview feedback submitted', 'success');
        refreshApex(this.wiredResult);
    }

    closeScheduleModal() {
        this.showScheduleModal = false;
        this.activeAppId = null;
    }

    closeCompleteModal() {
        this.showCompleteModal = false;
        this.activeInterviewId = null;
        this.activeAppId = null;
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({ title, message, variant })
        );
    }
}