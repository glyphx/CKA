
# CKA Lab Setup with Google Cloud and Terraform

Welcome to this CKA (Certified Kubernetes Administrator) lab setup guide! This project provides an automated way to create a Kubernetes cluster using Google Cloud and Terraform.

## Prerequisites

Before you begin, ensure you have the following installed and configured:

- [Google Cloud SDK](https://cloud.google.com/sdk)
- [Terraform](https://www.terraform.io)
- A Google Cloud Platform account with appropriate permissions to create resources

## Step 1: Enable Required APIs

### Using the Google Cloud Console GUI

1. Go to the [Google Cloud Console](https://console.cloud.google.com).
2. In the left sidebar, navigate to **APIs & Services** > **Library**.
3. In the search bar, type "Cloud Resource Manager API" and select it from the results.
4. Click the **Enable** button.
5. Repeat the same steps for the "Compute Engine API".

### Using the gcloud CLI

Ensure the following APIs are enabled in your Google Cloud project:

1. **Cloud Resource Manager API**:
   ```sh
   gcloud services enable cloudresourcemanager.googleapis.com
   ```

2. **Compute Engine API**:
   ```sh
   gcloud services enable compute.googleapis.com
   ```

![Enable APIs](API.png)

## Step 2: Set Up Google Cloud Service Account

### Using the Google Cloud Console GUI

1. Go to the [Google Cloud Console](https://console.cloud.google.com).
2. Navigate to **IAM & Admin** > **Service Accounts**.
3. Click on **Create Service Account**.
4. Provide a name and description for the service account.
5. Click on **Create and Continue**.
6. Assign the following roles to the service account:
   - Compute Admin
   - Editor
   - Secret Manager Admin
7. Click on **Done**.
8. After creating the service account, go to the service account details and create a new key. Download the key file in JSON format and save it to a secure location.

![Service Account Setup](SA.png)

## Step 3: Clone the Repository

```sh
git clone https://github.com/glyphx/CKA.git
cd CKA
```

## Step 4: Configure Variables

Update the `variables.tf` file in the root of the project and add your GCP credentials and desired configuration:

```hcl
project               = "your-gcp-project-id"
service_account_email = "your-service-account-email"
credentials_file      = "path-to-your-gcp-credentials-file.json"
region                = "your-region"
zone                  = "your-zone"
username              = "your-username"
machine_type          = "e2-small"
image                 = "ubuntu-os-cloud/ubuntu-2004-lts"
pod_network_cidr      = "10.244.0.0/16"
control_plane_count   = 1
worker_count          = 2
```

## Step 5: Initialize and Apply Terraform

Initialize Terraform:

```sh
terraform init
```

Review the Terraform plan:

```sh
terraform plan
```

Apply the Terraform configuration:

```sh
terraform apply
```

Confirm the action by typing `yes` when prompted.

## Step 6: Accessing the Kubernetes Cluster

After the Terraform configuration completes, your Kubernetes cluster will be ready. The master node will have `kubectl` configured to manage the cluster. You can SSH into the master node to start managing your cluster:

```sh
gcloud secrets versions access latest --secret="kubernetes-key" > ~/.ssh/kubernetes_key && chmod 600 ~/.ssh/kubernetes_key && ssh-keygen -y -f ~/.ssh/kubernetes_key > ~/.ssh/kubernetes_key.pub && gcloud compute ssh --zone "us-west1-a" "k8s-master" --ssh-key-file=~/.ssh/kubernetes_key
```

Once logged into the master node, you can use `kubectl` to manage your cluster:

```sh
kubectl get nodes
```

## Cleanup

To destroy the resources created by Terraform, run:

```sh
terraform destroy
```

## Troubleshooting

If you encounter any issues, please check the logs on the master and worker nodes located in `/var/log/install.log` & `/var/log/startup-script.log` for detailed error messages.

## Contributing

Contributions are welcome! Please submit a pull request with your changes.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

## Contact

For any questions or feedback, please open an issue on GitHub or reach out via email.

---

For more details and the latest updates, visit the [CKA GitHub repository](https://github.com/glyphx/CKA).
