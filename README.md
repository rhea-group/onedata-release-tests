# onedata-release-tests

# Deploying onedata on exoscale
- Edit exo.tvars and place your credentials.
- Get a space support token from onezone, (e.g., from https://onedata.hnsc.otc-service.com) and place it in variables.tf as support-token-ceph.
- Run:

```
terraform apply -var-file exo.tvars -var project=<name>
```


# Uninstalling or re-installing
Before uninstalling make sure that the providers have been deregistered from the oneproviders management web
console. If this is not done the onezone admin will have to remove them manually and until then oneproviders with the same project name will fail to deploy.
