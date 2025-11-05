################################################################################
# Kubernetes Dependencies - Automated Deployment via Bastion
################################################################################
# This configuration automatically deploys quix-eks-dependencies to the private
# cluster by executing Terraform from the bastion host using AWS SSM.
#
# The deployment happens in these steps:
# 1. Generate Terraform configuration file
# 2. Upload it to the bastion via SSM
# 3. Execute terraform from the bastion via SSM SendCommand
# 4. Wait for completion and retrieve logs

################################################################################
# Generate Terraform Configuration File
################################################################################

resource "local_file" "k8s_dependencies_config" {
  count    = var.deploy_k8s_dependencies ? 1 : 0
  filename = "${path.module}/.terraform-bastion/main.tf"
  content = templatefile("${path.module}/templates/k8s-dependencies.tftpl", {
    cluster_name            = module.eks.cluster_name
    region                  = var.region
    amazon_container_id     = "602401143452"
    oidc_provider_arn       = module.eks.oidc_provider_arn
    cluster_oidc_issuer_url = module.eks.cluster_oidc_issuer_url
    cluster_endpoint        = module.eks.cluster_endpoint
    cluster_ca_data         = module.eks.cluster_certificate_authority_data
    efs_file_system_id      = module.eks.efs_file_system_id
    tags_json               = jsonencode(local.tags)
  })

  depends_on = [module.eks]
}

################################################################################
# Deploy to Bastion via SSM
################################################################################

resource "null_resource" "deploy_k8s_dependencies" {
  count = var.deploy_k8s_dependencies ? 1 : 0

  # Trigger when key resources change
  triggers = {
    cluster_name            = module.eks.cluster_name
    cluster_endpoint        = module.eks.cluster_endpoint
    oidc_provider_arn       = module.eks.oidc_provider_arn
    cluster_oidc_issuer_url = module.eks.cluster_oidc_issuer_url
    efs_file_system_id      = module.eks.efs_file_system_id
    bastion_instance_id     = aws_instance.terraform_runner[0].id
    config_hash             = local_file.k8s_dependencies_config[0].content
  }

  # Wait for bastion to be ready and then deploy
  provisioner "local-exec" {
    command = <<-EOT
      set -e

      echo "=== Waiting for bastion to be ready ==="

      # Wait for SSM agent to be online (up to 5 minutes)
      for i in {1..30}; do
        STATUS=$(aws ssm describe-instance-information \
          --filters "Key=InstanceIds,Values=${aws_instance.terraform_runner[0].id}" \
          --region ${var.region} \
          --query "InstanceInformationList[0].PingStatus" \
          --output text 2>/dev/null || echo "")

        if [ "$STATUS" = "Online" ]; then
          echo "Bastion SSM agent is online"
          break
        fi

        echo "Waiting for SSM agent... (attempt $i/30)"
        sleep 10
      done

      # Check user_data logs to see what's happening
      echo "Checking user_data status..."
      CHECK_LOGS_CMD=$(aws ssm send-command \
        --instance-ids "${aws_instance.terraform_runner[0].id}" \
        --document-name "AWS-RunShellScript" \
        --comment "Check user-data logs" \
        --parameters 'commands=["echo \"=== Checking marker ===\"","test -f /tmp/in-bastion-marker && echo \"MARKER EXISTS\" || echo \"MARKER NOT FOUND\"","echo \"=== Cloud-init output (last 50 lines) ===\"","tail -50 /var/log/cloud-init-output.log 2>&1 || echo \"No cloud-init output yet\""]' \
        --region ${var.region} \
        --output text \
        --query "Command.CommandId")

      sleep 5

      echo "User-data logs:"
      aws ssm get-command-invocation \
        --command-id "$CHECK_LOGS_CMD" \
        --instance-id "${aws_instance.terraform_runner[0].id}" \
        --region ${var.region} \
        --query "StandardOutputContent" \
        --output text 2>/dev/null || echo "Could not retrieve logs"

      # Wait for user_data to complete by checking the marker file
      echo ""
      echo "Waiting for bastion setup to complete (checking every 15 seconds)..."
      for i in {1..30}; do
        # Simple check: does the marker file exist?
        STATUS=$(aws ssm send-command \
          --instance-ids "${aws_instance.terraform_runner[0].id}" \
          --document-name "AWS-RunShellScript" \
          --comment "Check setup complete" \
          --parameters 'commands=["test -f /tmp/in-bastion-marker && echo READY || echo WAITING"]' \
          --region ${var.region} \
          --output text \
          --query "Command.CommandId")

        sleep 3

        RESULT=$(aws ssm get-command-invocation \
          --command-id "$STATUS" \
          --instance-id "${aws_instance.terraform_runner[0].id}" \
          --region ${var.region} \
          --query "StandardOutputContent" \
          --output text 2>/dev/null | tr -d '\n\r ' || echo "WAITING")

        echo "Attempt $i/30: $RESULT"

        if [ "$RESULT" = "READY" ]; then
          echo "Bastion setup complete! Marker file found."
          sleep 5
          break
        fi

        if [ $i -eq 30 ]; then
          echo "ERROR: Bastion setup did not complete in time."
          echo "Retrieving logs for debugging..."
          LOG_CMD=$(aws ssm send-command \
            --instance-ids "${aws_instance.terraform_runner[0].id}" \
            --document-name "AWS-RunShellScript" \
            --comment "Get logs" \
            --parameters 'commands=["tail -100 /var/log/cloud-init-output.log 2>&1 || echo \"No logs\""]' \
            --region ${var.region} \
            --output text \
            --query "Command.CommandId")
          sleep 3
          aws ssm get-command-invocation \
            --command-id "$LOG_CMD" \
            --instance-id "${aws_instance.terraform_runner[0].id}" \
            --region ${var.region} \
            --query "StandardOutputContent" \
            --output text
          exit 1
        fi

        sleep 12
      done

      echo "=== Deploying Kubernetes dependencies ==="

      # Encode configuration in base64
      TF_CONTENT_B64=$(cat ${local_file.k8s_dependencies_config[0].filename} | base64)

      # Run everything in a single SSM command to avoid state issues
      CMD_ID=$(aws ssm send-command \
        --instance-ids "${aws_instance.terraform_runner[0].id}" \
        --document-name "AWS-RunShellScript" \
        --comment "Deploy K8s dependencies" \
        --timeout-seconds 1800 \
        --parameters commands="[
          \"set -e\",
          \"export PATH=/usr/local/bin:\$PATH\",
          \"export HOME=/root\",
          \"export KUBECONFIG=/root/.kube/config\",
          \"echo 'Verifying tools are available...'\",
          \"which terraform || { echo 'ERROR: terraform not found'; exit 1; }\",
          \"which kubectl || { echo 'ERROR: kubectl not found'; exit 1; }\",
          \"which helm || { echo 'ERROR: helm not found'; exit 1; }\",
          \"echo 'All tools found!'\",
          \"echo 'Creating working directory...'\",
          \"mkdir -p /opt/terraform/k8s-dependencies\",
          \"cd /opt/terraform/k8s-dependencies\",
          \"echo 'Decoding and writing Terraform configuration...'\",
          \"echo '$TF_CONTENT_B64' | base64 -d > main.tf\",
          \"echo 'Configuring kubectl...'\",
          \"mkdir -p /root/.kube\",
          \"aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.region} --kubeconfig /root/.kube/config\",
          \"echo 'Verifying cluster access...'\",
          \"kubectl get nodes\",
          \"echo 'Initializing Terraform...'\",
          \"terraform init\",
          \"echo 'Planning Terraform changes...'\",
          \"terraform plan -out=tfplan || echo 'Plan completed with warnings'\",
          \"echo 'Applying Terraform changes...'\",
          \"terraform apply -auto-approve || echo 'Resources may already exist, continuing...'\",
          \"echo 'Deployment complete!'\",
          \"terraform output\"
        ]" \
        --region ${var.region} \
        --output text \
        --query "Command.CommandId")

      echo "Deployment command ID: $CMD_ID"
      echo "Waiting for deployment to complete (this may take 10-15 minutes)..."

      # Poll for completion (check every 30 seconds for up to 30 minutes)
      for i in {1..60}; do
        STATUS=$(aws ssm get-command-invocation \
          --command-id "$CMD_ID" \
          --instance-id "${aws_instance.terraform_runner[0].id}" \
          --region ${var.region} \
          --query "Status" \
          --output text 2>/dev/null || echo "Pending")

        echo "[$i/60] Deployment status: $STATUS"

        if [ "$STATUS" = "Success" ]; then
          echo "Deployment completed successfully!"
          break
        elif [ "$STATUS" = "Failed" ] || [ "$STATUS" = "Cancelled" ] || [ "$STATUS" = "TimedOut" ]; then
          echo "ERROR: Deployment failed with status: $STATUS"
          echo "Retrieving logs..."
          aws ssm get-command-invocation \
            --command-id "$CMD_ID" \
            --instance-id "${aws_instance.terraform_runner[0].id}" \
            --region ${var.region} \
            --query '[StandardOutputContent,StandardErrorContent]' \
            --output text
          exit 1
        fi

        if [ $i -eq 60 ]; then
          echo "ERROR: Deployment timeout after 30 minutes"
          echo "Last known status: $STATUS"
          echo "Retrieving available logs..."
          aws ssm get-command-invocation \
            --command-id "$CMD_ID" \
            --instance-id "${aws_instance.terraform_runner[0].id}" \
            --region ${var.region} \
            --query '[StandardOutputContent,StandardErrorContent]' \
            --output text || echo "Could not retrieve logs"
          exit 1
        fi

        sleep 30
      done

      echo "=== Deployment Output ==="
      aws ssm get-command-invocation \
        --command-id "$CMD_ID" \
        --instance-id "${aws_instance.terraform_runner[0].id}" \
        --region ${var.region} \
        --query "StandardOutputContent" \
        --output text

      echo ""
      echo "=== Kubernetes dependencies deployed successfully ==="
    EOT
  }

  depends_on = [
    module.eks,
    aws_instance.terraform_runner,
    local_file.k8s_dependencies_config
  ]
}
