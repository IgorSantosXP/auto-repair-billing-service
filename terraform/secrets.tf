# Read by the CI deploy job to build the Kubernetes secret of each environment.
# Mercado Pago credentials are filled in by hand (or left empty for fake mode).
resource "aws_secretsmanager_secret" "this" {
  name                    = "${var.project}/${var.service}"
  description             = "Billing database credentials and Mercado Pago settings"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "this" {
  secret_id = aws_secretsmanager_secret.this.id

  secret_string = jsonencode({
    host                        = aws_db_instance.this.address
    port                        = aws_db_instance.this.port
    username                    = var.db_username
    password                    = random_password.db.result
    mercado_pago_mode           = "fake"
    mercado_pago_access_token   = ""
    mercado_pago_webhook_secret = ""
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}
