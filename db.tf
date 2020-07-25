resource "digitalocean_database_cluster" "mysql-example" {
  name       = "example-mysql-cluster"
  engine     = "mysql"
  version    = "8"
  size       = "db-s-1vcpu-1gb"
  region     = "nyc1"
  node_count = 1
}

resource "digitalocean_database_user" "user-example" {
  cluster_id = digitalocean_database_cluster.mysql-example.id
  name       = "blockshare"
}

resource "digitalocean_database_db" "database-example" {
  cluster_id = digitalocean_database_cluster.mysql-example.id
  name       = "blockshare"
}

resource "digitalocean_database_firewall" "example-fw" {
  cluster_id = digitalocean_database_cluster.mysql-example.id

  rule {
    type  = "k8s"
    value = digitalocean_kubernetes_cluster.k8s.name
  }
}
