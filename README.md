# onedata-release-tests

# Prerequisites
- terraform with providers plugins installed
- ssh-agent configured
- access to a onezone (as a user)

# Deploying onedata on exoscale
- run ssh-agent and add your key. It will further be used to login into the created VMs.
- Edit exo.tvars and place your credentials.
- Get a space support token from onezone, (e.g., from https://onedata.hnsc.otc-service.com) and place it in variables.tf as support-token-ceph.
- Get your access token from onezone and put it in exo.tvars
- Put your new onepanel password in exo.tvars
- Create a space and put its name in variables.tf
- If you need more VMs or different VM flavors modify defaults in variables.tf
- Then run:

```
terraform apply -var-file exo.tvars -var project=<name>
```

# Testing
Login to k8s master. There are jobs definitions in the home directory.
## Prepare sysbench files
Sysbench files will be placed in your-space/ceph/sysb.*. Each client will have its own directory with test files. To run the job issue:
```
kubectl create -f w-test-sysb-prep-job.yaml
```

## Example command flow 

### Prepare ssh 
```
eval `ssh-agent`
ssh-add
```
### Download the scripts
```
git clone https://github.com/onedata/onedata-release-tests.git
```
### Configure 
```
cd exoscale
vi exo.tvars
vi variables.tf

```



# Uninstalling or re-installing
Before uninstalling make sure that the providers have been deregistered from the oneproviders management web
console. If this is not done the onezone admin will have to remove them manually and until then oneproviders with the same project name will fail to deploy.
