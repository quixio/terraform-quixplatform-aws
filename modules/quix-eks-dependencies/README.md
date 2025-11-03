<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >= 3.1 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 2.29 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.19.0 |
| <a name="provider_helm"></a> [helm](#provider\_helm) | 3.1.0 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | 2.38.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_iam_policy.nlb_controller](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.efs_csi](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.nlb_controller](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.efs_csi](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.nlb_controller](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [helm_release.efs_csi](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.nlb_controller](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.tigera_operator](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubernetes_storage_class_v1.ebs](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/storage_class_v1) | resource |
| [kubernetes_storage_class_v1.efs](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/storage_class_v1) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_amazon_container_id"></a> [amazon\_container\_id](#input\_amazon\_container\_id) | AWS account id hosting the EKS public ECR images | `string` | `"602401143452"` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | EKS cluster name | `string` | n/a | yes |
| <a name="input_cluster_oidc_issuer_url"></a> [cluster\_oidc\_issuer\_url](#input\_cluster\_oidc\_issuer\_url) | The URL on the EKS cluster OIDC Issuer | `string` | `null` | no |
| <a name="input_create_ebs_storage_class"></a> [create\_ebs\_storage\_class](#input\_create\_ebs\_storage\_class) | Whether to create the EBS storage class | `bool` | `true` | no |
| <a name="input_create_efs_storage_class"></a> [create\_efs\_storage\_class](#input\_create\_efs\_storage\_class) | Whether to create the EFS storage class | `bool` | `true` | no |
| <a name="input_ebs_storage_class_allow_volume_expansion"></a> [ebs\_storage\_class\_allow\_volume\_expansion](#input\_ebs\_storage\_class\_allow\_volume\_expansion) | Whether volumes from the EBS storage class support expansion | `bool` | `true` | no |
| <a name="input_ebs_storage_class_is_default"></a> [ebs\_storage\_class\_is\_default](#input\_ebs\_storage\_class\_is\_default) | Whether to mark the EBS storage class as default | `bool` | `true` | no |
| <a name="input_ebs_storage_class_name"></a> [ebs\_storage\_class\_name](#input\_ebs\_storage\_class\_name) | Name of the EBS storage class | `string` | `"gp3"` | no |
| <a name="input_ebs_storage_class_reclaim_policy"></a> [ebs\_storage\_class\_reclaim\_policy](#input\_ebs\_storage\_class\_reclaim\_policy) | Reclaim policy for the EBS storage class (Retain or Delete) | `string` | `"Delete"` | no |
| <a name="input_ebs_storage_class_volume_binding_mode"></a> [ebs\_storage\_class\_volume\_binding\_mode](#input\_ebs\_storage\_class\_volume\_binding\_mode) | Volume binding mode for the EBS storage class (Immediate or WaitForFirstConsumer) | `string` | `"WaitForFirstConsumer"` | no |
| <a name="input_ebs_volume_type"></a> [ebs\_volume\_type](#input\_ebs\_volume\_type) | EBS volume type for the storage class (gp2, gp3, io1, etc.) | `string` | `"gp3"` | no |
| <a name="input_efs_csi_namespace"></a> [efs\_csi\_namespace](#input\_efs\_csi\_namespace) | Namespace for the EFS CSI controller | `string` | `"kube-system"` | no |
| <a name="input_efs_csi_role_arn"></a> [efs\_csi\_role\_arn](#input\_efs\_csi\_role\_arn) | IAM role ARN for the EFS CSI controller | `string` | `null` | no |
| <a name="input_efs_csi_service_account"></a> [efs\_csi\_service\_account](#input\_efs\_csi\_service\_account) | Service account name for the EFS CSI controller | `string` | `"efs-csi-controller-sa"` | no |
| <a name="input_efs_file_system_id"></a> [efs\_file\_system\_id](#input\_efs\_file\_system\_id) | ID of the backing EFS file system | `string` | `null` | no |
| <a name="input_efs_storage_class_name"></a> [efs\_storage\_class\_name](#input\_efs\_storage\_class\_name) | Name of the EFS storage class | `string` | `"efs-sc"` | no |
| <a name="input_efs_storage_class_reclaim_policy"></a> [efs\_storage\_class\_reclaim\_policy](#input\_efs\_storage\_class\_reclaim\_policy) | Reclaim policy for the EFS storage class (Retain or Delete) | `string` | `"Retain"` | no |
| <a name="input_enable_aws_load_balancer_controller"></a> [enable\_aws\_load\_balancer\_controller](#input\_enable\_aws\_load\_balancer\_controller) | Deploy the AWS Load Balancer Controller via Helm | `bool` | `true` | no |
| <a name="input_enable_calico"></a> [enable\_calico](#input\_enable\_calico) | Deploy Calico via Helm for network policy enforcement | `bool` | `true` | no |
| <a name="input_enable_efs_csi_addon"></a> [enable\_efs\_csi\_addon](#input\_enable\_efs\_csi\_addon) | Deploy the EFS CSI driver via Helm | `bool` | `true` | no |
| <a name="input_nlb_controller_namespace"></a> [nlb\_controller\_namespace](#input\_nlb\_controller\_namespace) | Namespace for the AWS Load Balancer Controller | `string` | `"kube-system"` | no |
| <a name="input_nlb_controller_role_arn"></a> [nlb\_controller\_role\_arn](#input\_nlb\_controller\_role\_arn) | IAM role ARN for the AWS Load Balancer Controller | `string` | `null` | no |
| <a name="input_nlb_controller_service_account"></a> [nlb\_controller\_service\_account](#input\_nlb\_controller\_service\_account) | Service account used by the AWS Load Balancer Controller | `string` | `"aws-load-balancer-controller"` | no |
| <a name="input_oidc_provider_arn"></a> [oidc\_provider\_arn](#input\_oidc\_provider\_arn) | ARN of the OIDC Provider for the EKS cluster | `string` | `null` | no |
| <a name="input_region"></a> [region](#input\_region) | AWS region where the cluster lives | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to all resources created by this module | `map(string)` | <pre>{<br/>  "Customer": "Quix",<br/>  "Environment": "Production"<br/>}</pre> | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | Name of the EKS cluster |
| <a name="output_cluster_region"></a> [cluster\_region](#output\_cluster\_region) | AWS region where the cluster is located |
| <a name="output_ebs_storage_class_enabled"></a> [ebs\_storage\_class\_enabled](#output\_ebs\_storage\_class\_enabled) | Whether the EBS storage class was created |
| <a name="output_ebs_storage_class_is_default"></a> [ebs\_storage\_class\_is\_default](#output\_ebs\_storage\_class\_is\_default) | Whether the EBS storage class is set as default |
| <a name="output_ebs_storage_class_name"></a> [ebs\_storage\_class\_name](#output\_ebs\_storage\_class\_name) | Name of the EBS storage class if created |
| <a name="output_ebs_storage_class_provisioner"></a> [ebs\_storage\_class\_provisioner](#output\_ebs\_storage\_class\_provisioner) | Storage provisioner used by the EBS storage class |
| <a name="output_ebs_storage_class_volume_type"></a> [ebs\_storage\_class\_volume\_type](#output\_ebs\_storage\_class\_volume\_type) | EBS volume type configured in the storage class |
| <a name="output_efs_csi_enabled"></a> [efs\_csi\_enabled](#output\_efs\_csi\_enabled) | Whether the EFS CSI driver was enabled |
| <a name="output_efs_csi_helm_release_name"></a> [efs\_csi\_helm\_release\_name](#output\_efs\_csi\_helm\_release\_name) | Name of the EFS CSI driver Helm release |
| <a name="output_efs_csi_namespace"></a> [efs\_csi\_namespace](#output\_efs\_csi\_namespace) | Namespace where the EFS CSI driver is installed |
| <a name="output_efs_storage_class_name"></a> [efs\_storage\_class\_name](#output\_efs\_storage\_class\_name) | Name of the EFS storage class if created |
| <a name="output_efs_storage_class_provisioner"></a> [efs\_storage\_class\_provisioner](#output\_efs\_storage\_class\_provisioner) | Storage provisioner used by the EFS storage class |
| <a name="output_module_tags"></a> [module\_tags](#output\_module\_tags) | Tags applied to resources created by this module |
| <a name="output_nlb_controller_enabled"></a> [nlb\_controller\_enabled](#output\_nlb\_controller\_enabled) | Whether the AWS Load Balancer Controller was enabled |
| <a name="output_nlb_controller_namespace"></a> [nlb\_controller\_namespace](#output\_nlb\_controller\_namespace) | Namespace where the AWS Load Balancer Controller is installed |
| <a name="output_nlb_controller_service_account"></a> [nlb\_controller\_service\_account](#output\_nlb\_controller\_service\_account) | Service account used by the AWS Load Balancer Controller |
<!-- END_TF_DOCS -->