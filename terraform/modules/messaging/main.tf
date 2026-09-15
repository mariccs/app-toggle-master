resource "aws_sqs_queue" "events_dlq" {
  name                      = "${var.queue_name}-dlq"
  message_retention_seconds = 1209600
}

resource "aws_sqs_queue" "events" {
  name                       = var.queue_name
  visibility_timeout_seconds = var.visibility_timeout_seconds
  message_retention_seconds  = 86400

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.events_dlq.arn
    maxReceiveCount      = 5
  })
}
