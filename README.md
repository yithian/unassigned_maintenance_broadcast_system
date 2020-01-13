## Unassigned Maintenance Broadcast System
This is a utility that queries the [OpenShift Dedicated Portal API](https://github.com/openshift/dedicated.openshift.com#api) and alerts the team if there are upcoming maintenances that do not have an SRE assigned.

### Requirements
* A user on the Dedicated Portal with an access token
* Access to a mail server that can deliver mail to your recipient

### Setup
1. Log into the Dedicated Portal, note your account name and generate an access token.
2. Decide the from and to addresses for the notifications
3. Configure an OpenShift project to run the util:
  1. `oc new-project unassigned-maintenance-broadcast-system --display-name="Unassigned Maintenance Broadcast System" --description="poll the dedicated portal API to find upcoming scheduled maintenances which are still unassigned"`
  2. `oc create -f openshift_resources/buildconfig.yml`
  3. `cp openshift_resources/config_secret.yml.template openshift_resources/config_secret.yml`
  4. fill out the stringData entries in `openshift_resources/config_secret.yml`
  5. `oc create -f openshift_resources/config_secret.yml`
  6. adjust the schedule in `openshift_resources/cronjob.yml`
  6. `oc create -f openshift_resources/cronjob.yml`
