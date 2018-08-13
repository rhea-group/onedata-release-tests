# onedata-release-tests

These scripts deploy onedata testbed consisting of:
- Ceph cluster
- Oneprovider with Ceph storage
- Oneprovider with POSIX (local disk) storage
- Kubernetes cluster
- Grafana server

# Prerequisites
- terraform with providers plugins installed
- ssh-agent configured
- access to a onezone (as a user)

# Deploying onedata
## Exoscale
- Change directory to exoscale
- Edit exo.tvars and place your exoscale credentials.
- Get your access token from onezone and put it in exo.tvars
- Put your new onepanel password in exo.tvars

## OTC
- Change directory to otc
- Edit otc.tvars and place your exoscale credentials.
- Get your access token from onezone and put it in otc.tvars
- Put your new onepanel password in otc.tvars

## Exoscale and OTC

- run ssh-agent and add your key. It will further be used to login into the created VMs.
- Create a space and put its name in variables.tf
- Get a space support token from onezone, (e.g., from https://onedata.hnsc.otc-service.com) and place it in variables.tf as support-token-ceph.
- If you need more VMs or different VM flavors modify defaults in variables.tf
- Then run:

```
terraform apply -var-file exo.tvars -var project=<name>
```

# Testing
Testing the performance of data access from many concurrent clients is realized by running parallel kubernetes jobs on the k8s cluster. Relevant YAML files with job definitions have been prepared. The following scenarios/files have been prepared:
- Sequential writes to local storage (Ceph): w-test-sysb-seqwr-job.yaml
- Sequential reads from local storage (Ceph): r-test-sysb-seqrd-job.yaml
- Random writes to local storage (Ceph): w-test-sysb-rndwr-job.yaml
- Random reads to local storage (Ceph): r-test-sysb-rndrd-job.yaml
- Sequential reads from remote storage (POSIX/NFS): r-test-dd-seqrd-job.yaml
- Random reads from remote storage (POSIX/NFS): r-test-ioping-rndrd-job.yaml
The jobs definitions are in the home directory of the k8s master node. The local tests are done with sysbench while the remotes with dd or ioping. All the jobs have the parallelism set to 50.

## Prepare sysbench files
In order to use sysbench the test files need to be prepared. Sysbench files will be placed in your-space/ceph/sysb.*. Each client will have its own directory with test files. To run the preparation job issue:
```
kubectl create -f w-test-sysb-prep-job.yaml
```
After the test is finished and data analized the job should be deleted to free resources for another test. Use `kubectl delete job <job-name>` to do so.

## Running tests
Use kubectl `create -f <job-definition.yaml>` to run one of the above access scenarios.
Before repeating the remote access test make sure the replica of rt directory on the first ceph-supported provider has been invalidated. This can done from the Web GUI.  

## Observing metrics
The performance metrics can be observed with grafana. To do so go to the grafana IP address using a web browser and login using admin:admin. 

## DESY test
The DESY test generates a HDF5 file on imported POSIX/NFS storage and reads it on the other side. The reverse case is also tested. In order to run the test:
- on the host op2 run:
```
./desy-replica-agent.sh
```
- on the host op2 in another terminal run:
```
./run-desy.sh
```

# Upgrading onedata
- Login to each oneprovider as user centos and run:
```
onedatify upgrade -v <new-version>
```
- Login to k8s master and replace the oneclient image in the yaml files for each job 
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
### Run terraform
```
terraform apply -var-file exo.tvars -var project=odt
```


# Uninstalling or re-installing
Before uninstalling make sure that the providers have been deregistered from the oneproviders management web
console. If this is not done the onezone admin will have to remove them manually and until then oneproviders with the same project name will fail to deploy.
