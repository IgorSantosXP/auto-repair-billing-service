output "queue_urls" {
  value = { for env, queue in aws_sqs_queue.this : env => queue.url }
}

output "dlq_urls" {
  value = { for env, queue in aws_sqs_queue.dlq : env => queue.url }
}

output "role_arn" {
  value = aws_iam_role.this.arn
}

output "db_endpoint" {
  value = aws_db_instance.this.address
}

output "secret_name" {
  value = aws_secretsmanager_secret.this.name
}
