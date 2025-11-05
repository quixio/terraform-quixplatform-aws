<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0 |
| <a name="requirement_null"></a> [null](#requirement\_null) | >= 3.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.0 |
| <a name="provider_null"></a> [null](#provider\_null) | >= 3.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_eks"></a> [eks](#module\_eks) | terraform-aws-modules/eks/aws | ~> 20.0 |
| <a name="module_vpc"></a> [vpc](#module\_vpc) | terraform-aws-modules/vpc/aws | ~> 5.0 |
| <a name="module_vpc_endpoints"></a> [vpc\_endpoints](#module\_vpc\_endpoints) | terraform-aws-modules/vpc/aws//modules/vpc-endpoints | ~> 5.0 |

## Resources

| Name | Type |
|------|------|
| [aws_efs_backup_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/efs_backup_policy) | resource |
| [aws_efs_file_system.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/efs_file_system) | resource |
| [aws_efs_mount_target.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/efs_mount_target) | resource |
| [aws_efs_replication_configuration.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/efs_replication_configuration) | resource |
| [aws_iam_policy.cert_manager_route53](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.ebs_kms](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.cert_manager](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.ebs_csi](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.cert_manager](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.ebs_csi](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.ebs_kms](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_route53_zone.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_zone) | resource |
| [null_resource.createcontext](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [aws_availability_zones.available](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_route_tables.existing_private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/route_tables) | data source |
| [aws_route_tables.existing_public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/route_tables) | data source |
| [aws_subnet.existing_private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnet) | data source |
| [aws_subnet.existing_public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnet) | data source |
| [aws_vpc.existing](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/vpc) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_amazon_container_id"></a> [amazon\_container\_id](#input\_amazon\_container\_id) | The Amazon Container ID | `string` | `"602401143452"` | no |
| <a name="input_attach_kms_permissions_to_ebs_role"></a> [attach\_kms\_permissions\_to\_ebs\_role](#input\_attach\_kms\_permissions\_to\_ebs\_role) | Attach KMS key permissions to EBS CSI role when EKS has a KMS key configured | `bool` | `true` | no |
| <a name="input_azs"></a> [azs](#input\_azs) | The number of availability zones for the cluster. Required when create\_vpc is true | `number` | `null` | no |
| <a name="input_cert_manager_namespace"></a> [cert\_manager\_namespace](#input\_cert\_manager\_namespace) | Namespace where cert-manager is deployed | `string` | `"quix-cert-manager"` | no |
| <a name="input_cert_manager_service_account"></a> [cert\_manager\_service\_account](#input\_cert\_manager\_service\_account) | Service account name for cert-manager | `string` | `"cert-manager"` | no |
| <a name="input_cluster_endpoint_public_access"></a> [cluster\_endpoint\_public\_access](#input\_cluster\_endpoint\_public\_access) | Indicates whether or not the Amazon EKS public API server endpoint is enabled | `bool` | `true` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Name of the EKS cluster | `string` | `"Cluster"` | no |
| <a name="input_cluster_version"></a> [cluster\_version](#input\_cluster\_version) | Kubernetes `<major>.<minor>` version to use for the EKS cluster (i.e.: `1.31`) | `string` | `"1.32"` | no |
| <a name="input_create_backup_policy"></a> [create\_backup\_policy](#input\_create\_backup\_policy) | Determines whether a backup policy is created | `bool` | `true` | no |
| <a name="input_create_cert_manager_role"></a> [create\_cert\_manager\_role](#input\_create\_cert\_manager\_role) | Whether to create IAM role for cert-manager | `bool` | `false` | no |
| <a name="input_create_replication_configuration"></a> [create\_replication\_configuration](#input\_create\_replication\_configuration) | Determines whether a replication configuration is created | `bool` | `false` | no |
| <a name="input_create_route53_zone"></a> [create\_route53\_zone](#input\_create\_route53\_zone) | Whether to create a Route 53 hosted zone | `bool` | `false` | no |
| <a name="input_create_s3_endpoint"></a> [create\_s3\_endpoint](#input\_create\_s3\_endpoint) | Whether to create S3 VPC endpoint. Set to false if endpoint already exists | `bool` | `true` | no |
| <a name="input_create_vpc"></a> [create\_vpc](#input\_create\_vpc) | Whether to create a new VPC. Set to false to use an existing VPC | `bool` | `true` | no |
| <a name="input_creation_token"></a> [creation\_token](#input\_creation\_token) | A unique name (a maximum of 64 characters are allowed) used as reference when creating the Elastic File System to ensure idempotent file system creation. By default generated by Terraform | `string` | `null` | no |
| <a name="input_domain_name"></a> [domain\_name](#input\_domain\_name) | The domain name for the Route 53 hosted zone | `string` | `"example.com"` | no |
| <a name="input_ebs_csi_namespace"></a> [ebs\_csi\_namespace](#input\_ebs\_csi\_namespace) | Namespace of the EBS CSI controller service account | `string` | `"kube-system"` | no |
| <a name="input_ebs_csi_service_account"></a> [ebs\_csi\_service\_account](#input\_ebs\_csi\_service\_account) | Service account name of the EBS CSI controller | `string` | `"ebs-csi-controller-sa"` | no |
| <a name="input_enable_backup_policy"></a> [enable\_backup\_policy](#input\_enable\_backup\_policy) | Determines whether a backup policy is `ENABLED` or `DISABLED` | `bool` | `true` | no |
| <a name="input_enable_cluster_creator_admin_permissions"></a> [enable\_cluster\_creator\_admin\_permissions](#input\_enable\_cluster\_creator\_admin\_permissions) | Indicates whether or not the Amazon EKS public API server endpoint is enabled | `bool` | `true` | no |
| <a name="input_enable_credentials_fetch"></a> [enable\_credentials\_fetch](#input\_enable\_credentials\_fetch) | Run aws eks get-credentials after creating the cluster | `bool` | `false` | no |
| <a name="input_enable_nat_gateway"></a> [enable\_nat\_gateway](#input\_enable\_nat\_gateway) | Whether to create a single NAT Gateway for private subnets. Only used when create\_vpc is true | `bool` | `true` | no |
| <a name="input_encrypted"></a> [encrypted](#input\_encrypted) | If `true`, the disk will be encrypted | `bool` | `true` | no |
| <a name="input_lifecycle_policy"></a> [lifecycle\_policy](#input\_lifecycle\_policy) | A file system [lifecycle policy](https://docs.aws.amazon.com/efs/latest/ug/API_LifecyclePolicy.html) object | `any` | `{}` | no |
| <a name="input_node_pools"></a> [node\_pools](#input\_node\_pools) | Map of node pools to create as EKS managed node groups | <pre>map(object({<br>    name          = string<br>    node_count    = number<br>    instance_size = string # maps to instance type<br>    disk_size     = number<br>    labels        = optional(map(string), {})<br>    taints = optional(list(object({<br>      key    = string<br>      value  = string<br>      effect = string # NoSchedule | PreferNoSchedule | NoExecute<br>    })), [])<br>  }))</pre> | <pre>{<br>  "default": {<br>    "disk_size": 75,<br>    "instance_size": "m6i.large",<br>    "labels": {},<br>    "name": "default",<br>    "node_count": 3,<br>    "taints": []<br>  }<br>}</pre> | no |
| <a name="input_private_subnet_ids"></a> [private\_subnet\_ids](#input\_private\_subnet\_ids) | List of existing private subnet IDs. Required when create\_vpc is false | `list(string)` | `[]` | no |
| <a name="input_private_subnets"></a> [private\_subnets](#input\_private\_subnets) | The private subnet CIDRs. Required when create\_vpc is true | `list(string)` | `[]` | no |
| <a name="input_public_subnet_ids"></a> [public\_subnet\_ids](#input\_public\_subnet\_ids) | List of existing public subnet IDs. Required when create\_vpc is false | `list(string)` | `[]` | no |
| <a name="input_public_subnets"></a> [public\_subnets](#input\_public\_subnets) | The public subnet CIDRs. Required when create\_vpc is true | `list(string)` | `[]` | no |
| <a name="input_region"></a> [region](#input\_region) | The AWS region | `string` | n/a | yes |
| <a name="input_replication_configuration_destination"></a> [replication\_configuration\_destination](#input\_replication\_configuration\_destination) | A destination configuration block | `any` | `{}` | no |
| <a name="input_singleaz"></a> [singleaz](#input\_singleaz) | The availability zone name to pin single-AZ resources (e.g., efs/mnt) | `string` | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | n/a | `map(string)` | <pre>{<br>  "Customer": "Quix",<br>  "Environment": "Production"<br>}</pre> | no |
| <a name="input_vpc_cidr"></a> [vpc\_cidr](#input\_vpc\_cidr) | The VPC CIDR. Required when create\_vpc is true | `string` | `null` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | ID of existing VPC. Required when create\_vpc is false | `string` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cert_manager_policy_arn"></a> [cert\_manager\_policy\_arn](#output\_cert\_manager\_policy\_arn) | ARN of the cert-manager Route53 policy |
| <a name="output_cert_manager_role_arn"></a> [cert\_manager\_role\_arn](#output\_cert\_manager\_role\_arn) | ARN of the cert-manager IAM role |
| <a name="output_cert_manager_service_account_annotation"></a> [cert\_manager\_service\_account\_annotation](#output\_cert\_manager\_service\_account\_annotation) | Annotation to add to the cert-manager service account |
| <a name="output_cluster_certificate_authority_data"></a> [cluster\_certificate\_authority\_data](#output\_cluster\_certificate\_authority\_data) | Base64 encoded certificate data required to communicate with the cluster |
| <a name="output_cluster_endpoint"></a> [cluster\_endpoint](#output\_cluster\_endpoint) | Endpoint for EKS control plane |
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | The name of the EKS cluster |
| <a name="output_cluster_oidc_issuer_url"></a> [cluster\_oidc\_issuer\_url](#output\_cluster\_oidc\_issuer\_url) | The URL on the EKS cluster OIDC Issuer |
| <a name="output_cluster_security_group_id"></a> [cluster\_security\_group\_id](#output\_cluster\_security\_group\_id) | Security group ID attached to the EKS cluster control plane |
| <a name="output_command_output"></a> [command\_output](#output\_command\_output) | The output of the aws command |
| <a name="output_ebs_csi_role_arn"></a> [ebs\_csi\_role\_arn](#output\_ebs\_csi\_role\_arn) | IAM role ARN used by the EBS CSI driver (if created) |
| <a name="output_efs_file_system_arn"></a> [efs\_file\_system\_arn](#output\_efs\_file\_system\_arn) | The ARN of the EFS file system |
| <a name="output_efs_file_system_dns_name"></a> [efs\_file\_system\_dns\_name](#output\_efs\_file\_system\_dns\_name) | The DNS name of the EFS file system |
| <a name="output_efs_file_system_id"></a> [efs\_file\_system\_id](#output\_efs\_file\_system\_id) | The ID of the EFS file system |
| <a name="output_node_security_group_id"></a> [node\_security\_group\_id](#output\_node\_security\_group\_id) | Security group ID attached to the EKS nodes |
| <a name="output_oidc_provider_arn"></a> [oidc\_provider\_arn](#output\_oidc\_provider\_arn) | ARN of the OIDC Provider for the EKS cluster |
| <a name="output_private_subnets"></a> [private\_subnets](#output\_private\_subnets) | List of IDs of private subnets |
| <a name="output_public_subnets"></a> [public\_subnets](#output\_public\_subnets) | List of IDs of public subnets |
| <a name="output_route53_zone_arn"></a> [route53\_zone\_arn](#output\_route53\_zone\_arn) | The Amazon Resource Name (ARN) of the Hosted Zone |
| <a name="output_route53_zone_id"></a> [route53\_zone\_id](#output\_route53\_zone\_id) | The hosted zone ID |
| <a name="output_route53_zone_name_servers"></a> [route53\_zone\_name\_servers](#output\_route53\_zone\_name\_servers) | The name servers for the hosted zone |
| <a name="output_vpc_cidr"></a> [vpc\_cidr](#output\_vpc\_cidr) | The CIDR block of the VPC |
| <a name="output_vpc_endpoints"></a> [vpc\_endpoints](#output\_vpc\_endpoints) | Array containing the full resource object and attributes for all endpoints created |
| <a name="output_vpc_id"></a> [vpc\_id](#output\_vpc\_id) | The ID of the VPC |
<!-- END_TF_DOCS -->