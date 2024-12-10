# Jenkins Setup on Google Cloud Platform using Terraform

This guide helps to set up a Jenkins server on Google Cloud Plaform (GCP) using Terraform.

## Prerequisites

Before you start, make sure you have the following:

1. **Google Cloud Account**: Sign up at [Google Cloud Console](https://console.cloud.google.com/).
2. **GCP Project**: Create a project in the Google Cloud Console to manage resources.
3. **Terraform Installed**: Install Terraform on your local machine. Refer to the [Terraform installation guide](https://www.terraform.io/downloads).
4. **Google Cloud SDK**: Install Google Cloud SDK on your local machine. Follow the instructions [here](https://cloud.google.com/sdk/docs/install).
5. **Service Account Key**: Create a service account in GCP with Editor access, and download its JSON key. (See instructions below)
6. **Activate APIs**: Enable the Compute Engine, Kubernetes Engine API  and Cloud Storage APIs in your GCP project.
7. **Set the variables in the terraform configuration** (see below)
8. **Ansible Installed**: Install Ansible on your local machine. Refer to the [Ansible installation guide](https://docs.ansible.com/ansible/latest/installation_guide/index.html).

### GCP Service Account
1. Create a Service Account in GCP

You need a service account key to allow Terraform to authenticate with GCP.

    Step 1: Go to the IAM & Admin > Service Accounts page in your GCP console.
    Step 2: Create a new service account:
        Name it something like terraform-admin.
        Assign the role Editor to give it permission to create and manage resources.
    Step 3: Create a JSON key for the service account and download it. This file is required for Terraform to authenticate with GCP.

2. Set Up Google Cloud SDK (gcloud) (this is optional)

   Install Google Cloud SDK on your local machine. This helps you interact with GCP from the command line:
   Follow the installation instructions for your OS from Google Cloud SDK.
   Initialize GCP by running:
3. 
```sh
   gcloud init
```
This will let you authenticate with your GCP account and select your project.

### GPC activation APIs

1. Go to the API & Services > Library page in your GCP console.
2. Search for the Compute Engine API and enable it.
3. Wait for the API to be enabled

## Script usage

You can use the `run-jenkins-install.sh` script to automate the Terraform setup process or just follow the step-by-step instructions below.
Asumming you have the prerequisites set up, you are ready to run the script.
2. create the `.terraform.tfvars` file
2. run the script
3. access Jenkins (with default init password displayed in the terminal at the end of the script)
4. follow the Jenkins setup wizard

The script will:
- Use **terraform** to create the Jenkins instance on GCP
- Display the **external IP** address of the Jenkins instance
- Store the **ssh key** to access the Jenkins instance
- update the **ansible inventory** file with the Jenkins instance IP
- Use **Ansible** to install Jenkins on the instance
- And finally, display the **initial admin password** to access Jenkins

```sh
 ~ Whanos/Jenkins$> ./run-jenkins-install.sh
```

## Step-by-Step Instructions (manual detailed instructions)

### 0. set up the environment for the deployment

create an env file to store the secrets

```bash
 ~ Whanos/Jenkins/terraform$> touch .env
```

```txt
JENKINS_ADMIN_PASSWORD=secureAdminPassword
JENKINS_USER_PASSWORD=secureUserPassword
```


### 1. Set Up Terraform Configuration

1. create a new file for terraform variables
    ```hcl
    variables.tf
    ```
    ```hcl
    variable "GCP_PROJECT_ID" {
      description = "The GCP project ID"
    }
    
    variable "SERVICE_ACCOUNT_KEY_PATH" {
      description = "The path to the service account key file"
    }
    
    variable "SERVICE_ACCOUNT_EMAIL" {
      description = "The service account email"
    }
    ```

2. Create a new file named `.terraform.tfvars` and add the following environment variables:

   ```
   project_id            = "<the GCP project ID>"
   service_account_key_path = "<the path to the service account key file>"
   service_account_email = "<the service account email / not owner email>"
   ```

3. The variables are load from the two files above


4. The main file is `main.tf` this file contains the terraform configuration to create the Jenkins instance on GCP.
   ```hcl
   main.tf
   ```

### 2. Initialize and Apply Terraform

1. **Initialize Terraform**:

   ```sh
 ~ Whanos/Jenkins/terraform$> terraform init
   ```

   This command downloads the necessary provider plugins.

2. **Plan the Deployment**:

   ```sh
   terraform plan
   ```

   Review the planned actions to verify what Terraform is going to create.

3. **Apply the Configuration**:

   ```sh
 ~ Whanos/Jenkins/terraform$> terraform apply
   ```

   Type `yes` when prompted to confirm the creation of resources.


### 3. Install Jenkins
After the Terraform configuration has successfully created your resources, find the external IP address of your Jenkins instance.

1. update the `ansible/inventory` file with the Jenkins instance IP
2. Run the Ansible playbook to install Jenkins on the instance:

   ```sh
   ansible-playbook -i ansible/inventory ansible/jenkins_setup.yml
   ```
_type `yes` if prompted to accept the ssh key fingerprint_

### 4. Access Jenkins

- After the Terraform configuration has successfully created your resources, find the external IP address of your Jenkins instance.
- Open a browser and navigate to `http://<EXTERNAL_IP>:8080`.
- Retrieve the initial admin password by running on the Jenkins instance:
  ```sh
  sudo cat /var/lib/jenkins/secrets/initialAdminPassword
  ```
- Follow the Jenkins setup wizard to complete the installation.

## Reset all the deployment resources on google cloud platform

To delete all the resources created by Terraform, run the following command:

```sh
 ~ Whanos/Jenkins/terraform$> terraform destroy
```
