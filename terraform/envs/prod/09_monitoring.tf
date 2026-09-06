# --- SNS topic: where both alerts go ---

resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-alerts"
  tags = var.tags
}

resource "aws_sns_topic_subscription" "alerts_email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# --- Metrics tracked (3, per the brief) ---
# 1. UnHealthyHostCount   (ALB target group)
# 2. HTTPCode_Target_5XX_Count (ALB target group)
# 3. TargetResponseTime   (ALB target group) — tracked via the dashboard/console,
#    not alarmed on directly; the two alarms below cover the two states that
#    actually need a human, per the brief's "2 alerts" requirement.

# --- Alert 1: unhealthy targets ---
# Trigger: 1+ unhealthy target for 2 consecutive 1-minute periods.
# Why it matters: this is the direct precursor to customer-facing 503s —
# catching it here means responding before customers notice, not after.
# Who receives it: on-call platform engineer (SNS email subscription above).
# First investigation step: check the target's health check reason in the
# target group console, then cross-reference ECS task logs for the same window.

resource "aws_cloudwatch_metric_alarm" "unhealthy_targets" {
  alarm_name          = "${var.project_name}-unhealthy-targets"
  alarm_description   = "1+ unhealthy target for 2 consecutive minutes — precedes customer-facing 503s."
  namespace           = "AWS/ApplicationELB"
  metric_name         = "UnHealthyHostCount"
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 2
  comparison_operator = "GreaterThanThreshold"
  threshold           = 0
  treat_missing_data  = "notBreaching"

  dimensions = {
    TargetGroup  = module.alb.target_groups["pulsesvc_tg"].arn_suffix
    LoadBalancer = module.alb.arn_suffix
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]
  tags          = var.tags
}

# --- Alert 2: elevated 5xx rate ---
# Trigger: more than 5 target-origin 5xx responses in a 5-minute window.
# Why it matters: direct customer impact, not just an infra-state signal —
# the target could show "healthy" while still returning application errors.
# Who receives it: on-call platform engineer.
# First investigation step: check ECS task logs for the same window and
# correlate against the timestamp of the most recent deployment.

resource "aws_cloudwatch_metric_alarm" "high_5xx_rate" {
  alarm_name          = "${var.project_name}-high-5xx-rate"
  alarm_description   = "More than 5 target-origin 5xx responses in 5 minutes."
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HTTPCode_Target_5XX_Count"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  comparison_operator = "GreaterThanThreshold"
  threshold           = 5
  treat_missing_data  = "notBreaching"

  dimensions = {
    TargetGroup  = module.alb.target_groups["pulsesvc_tg"].arn_suffix
    LoadBalancer = module.alb.arn_suffix
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]
  tags          = var.tags
}
