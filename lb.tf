# data "digitalocean_loadbalancer" "example" {
#   name   = "app"
#   region = "nyc1"
# 
#   forwarding_rule {
#     entry_port     = 80
#     entry_protocol = "http"
# 
#     target_port     = 80
#     target_protocol = "http"
#   }
# 
#   healthcheck {
#     port     = 22
#     protocol = "tcp"
#   }
# }
# 
# output "lb_output" {
#   value = data.digitalocean_loadbalancer.example.ip
# }
