resource "vultr_instance" "CONSOLE01" {
    plan = "vc2-2c-4gb"
    region = "cdg"
    os_id = 1946
    hostname = "CONSOLE01"
    enable_ipv6 = true
    backups = "disabled"
    ddos_protection = true
    activation_email = false
    ssh_key_ids = [ data.vultr_ssh_key.my_ssh_key.id ]
    vpc_ids = [ data.vultr_vpc.my_vpc.id ]
}

data "vultr_vpc" "my_vpc" {
  filter {
    name = "description"
    values = ["K3s Private Network"]
  }
}

data "vultr_ssh_key" "my_ssh_key" {
  filter {
    name = "name"
    values = [ "ub20-metairie" ]
  }
}
