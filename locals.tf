########################
# Shared locals
########################

locals {
  project_name = var.project_name
  tags = {
    Project     = local.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }

  # Simple nginx config and index.html
  nginx_conf = <<-EOT
    events {}
    http {
      server {
        listen 80 default_server;
        server_name _;
        location / {
          root /usr/share/nginx/html;
          index index.html;
        }
      }
    }
  EOT

  index_html = <<-EOT
    <!DOCTYPE html>
    <html>
      <head>
        <title>Hello from ECS Fargate</title>
      </head>
      <body>
        <h1>Hello, world!</h1>
        <p>Served by nginx in ECS Fargate.</p>
      </body>
    </html>
  EOT
}
