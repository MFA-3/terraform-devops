# CloudWatch Log Group for EKS Control Plane
resource "aws_cloudwatch_log_group" "eks" {
  count             = var.enable_cloudwatch_logs ? 1 : 0
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-eks-logs"
    }
  )
}

# CloudWatch Log Group for Application Logs
resource "aws_cloudwatch_log_group" "application" {
  count             = var.enable_cloudwatch_logs ? 1 : 0
  name              = "/aws/eks/${var.cluster_name}/application"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-application-logs"
    }
  )
}

# CloudWatch Log Group for Data Plane
resource "aws_cloudwatch_log_group" "dataplane" {
  count             = var.enable_cloudwatch_logs ? 1 : 0
  name              = "/aws/eks/${var.cluster_name}/dataplane"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-dataplane-logs"
    }
  )
}

# CloudWatch Log Group for Host
resource "aws_cloudwatch_log_group" "host" {
  count             = var.enable_cloudwatch_logs ? 1 : 0
  name              = "/aws/eks/${var.cluster_name}/host"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-host-logs"
    }
  )
}

# CloudWatch Metrics for Container Insights
resource "aws_cloudwatch_log_group" "performance" {
  count             = var.enable_container_insights ? 1 : 0
  name              = "/aws/containerinsights/${var.cluster_name}/performance"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-performance-logs"
    }
  )
}

# SNS Topic for Alerts
resource "aws_sns_topic" "alerts" {
  name              = "${var.cluster_name}-alerts"
  kms_master_key_id = var.kms_key_arn

  tags = var.tags
}

# CloudWatch Alarms for EKS Cluster
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "${var.cluster_name}-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "node_cpu_utilization"
  namespace           = "ContainerInsights"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors EKS node CPU utilization"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    ClusterName = var.cluster_name
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "high_memory" {
  alarm_name          = "${var.cluster_name}-high-memory"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "node_memory_utilization"
  namespace           = "ContainerInsights"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors EKS node memory utilization"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    ClusterName = var.cluster_name
  }

  tags = var.tags
}

# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.cluster_name}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          metrics = [
            ["ContainerInsights", "node_cpu_utilization", { stat = "Average" }],
            [".", "node_memory_utilization", { stat = "Average" }],
            [".", "node_filesystem_utilization", { stat = "Average" }]
          ]
          period = 300
          stat   = "Average"
          region = data.aws_region.current.name
          title  = "Node Resource Utilization"
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["ContainerInsights", "pod_cpu_utilization", { stat = "Average" }],
            [".", "pod_memory_utilization", { stat = "Average" }]
          ]
          period = 300
          stat   = "Average"
          region = data.aws_region.current.name
          title  = "Pod Resource Utilization"
        }
      }
    ]
  })
}

data "aws_region" "current" {}
