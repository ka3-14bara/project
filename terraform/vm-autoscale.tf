# Объявление переменных для конфиденциальных параметров

variable "folder_id" {
  type = string
}

variable "vm_user" {
  type = string
}

variable "ssh_key" {
  type      = string
  sensitive = true
}

# Настройка провайдера

terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
      version = ">= 0.47.0"
    }
  }
}

provider "yandex" {
  zone = "ru-central1-a"
}

# Создание сервисного аккаунта и назначение ему ролей

resource "yandex_iam_service_account" "for-vm" {
  name = "user"
}

resource "yandex_resourcemanager_folder_iam_member" "user" {
  folder_id = var.folder_id
  role      = "editor"
  member    = "serviceAccount:${yandex_iam_service_account.for-vm.id}"
}

# Создание облачной сети и подсетей

resource "yandex_vpc_network" "default" {
  name = "edfault"
}

resource "yandex_vpc_subnet" "private-net-a" {
  name           = "private-net-a"
  zone           = "ru-central1-a"
  v4_cidr_blocks = ["10.121.0.0/24"]
  network_id     = yandex_vpc_network.default.id
}

resource "yandex_vpc_subnet" "private-net-b" {
  name           = "private-net-b"
  zone           = "ru-central1-b"
  v4_cidr_blocks = ["10.120.0.0/24"]
  network_id     = yandex_vpc_network.default.id
}

resource "yandex_vpc_subnet" "public-net-b" {
  name           = "public-net-b"
  zone           = "ru-central1-b"
  v4_cidr_blocks = ["10.122.0.0/24"]
  network_id     = yandex_vpc_network.default.id
}

# Создание группы безопасности

resource "yandex_vpc_security_group" "zbx" {
  name                = "zabbix"
  network_id          = yandex_vpc_network.default.id
  egress {
    protocol          = "ANY"
    description       = "any"
    v4_cidr_blocks    = ["0.0.0.0/0"]
  }
  ingress {
    protocol          = "Any"
    description       = "postgre"
    v4_cidr_blocks    = ["0.0.0.0/0"]
    port              = 5432
  }
  ingress {
    protocol          = "Any"
    description       = "zabbix"
    predefined_target = ["0.0.0.0/0"]
    port              = 10050-10051
  }
  ingress {
    protocol          = "Any"
    predefined_target = ["0.0.0.0/0"]
    port              = 443
  }
  ingress {
    protocol          = "UDP"
    predefined_target = ["0.0.0.0/0"]
    port              = 162
  }
  ingress {
    protocol          = "UDP"
    predefined_target = ["0.0.0.0/0"]
    port              = 53
  }
  ingress {
    protocol          = "UDP"
    predefined_target = ["0.0.0.0/0"]
    port              = 123
  }
}

resource "yandex_vpc_security_group" "slf" {
  name                = "self"
  network_id          = yandex_vpc_network.default.id
  egress {
    protocol          = "ANY"
    description       = "any"
    v4_cidr_blocks    = ["0.0.0.0/0"]
  }
  ingress {
    protocol          = "Any"
    description       = "intern"
    v4_cidr_blocks    = ["0.0.0.0/0"]
  }
}

resource "yandex_vpc_security_group" "ssh" {
  name                = "ssh"
  network_id          = yandex_vpc_network.default.id
  egress {
    protocol          = "ANY"
    description       = "any"
    v4_cidr_blocks    = ["0.0.0.0/0"]
  }
  ingress {
    protocol          = "Any"
    description       = "for_ssh_traffic"
    v4_cidr_blocks    = ["0.0.0.0/0"]
    port              = 22
  }
}

resource "yandex_vpc_security_group" "kbn" {
  name                = "kibana"
  network_id          = yandex_vpc_network.default.id
  egress {
    protocol          = "ANY"
    description       = "any"
    v4_cidr_blocks    = ["0.0.0.0/0"]
  }
  ingress {
    protocol          = "Any"
    description       = "kibana"
    v4_cidr_blocks    = ["0.0.0.0/0"]
    port              = 5601
  }
}

resource "yandex_vpc_security_group" "http" {
  name                = "http"
  network_id          = yandex_vpc_network.default.id
  egress {
    protocol          = "ANY"
    description       = "any"
    v4_cidr_blocks    = ["0.0.0.0/0"]
  }
  ingress {
    protocol          = "Any"
    description       = "for_http_traffic"
    v4_cidr_blocks    = ["10.120.0.0/24", "10.121.0.0/24", "10.122.0.0/24"]
    port              = 80
  }
}

resource "yandex_vpc_security_group" "wb" {
  name                = "for-web"
  network_id          = yandex_vpc_network.default.id
  egress {
    protocol          = "ANY"
    description       = "any"
    v4_cidr_blocks    = ["0.0.0.0/0"]
  }
  ingress {
    protocol          = "Any"
    description       = "zabbix"
    v4_cidr_blocks    = ["0.0.0.0/0"]
    port              = 10050
  }
  ingress {
    protocol          = "Any"
    description       = "systemd"
    v4_cidr_blocks    = ["0.0.0.0/0"]
    port              = 53
  }
}

resource "yandex_vpc_security_group" "els" {
  name                = "elasticsearch"
  network_id          = yandex_vpc_network.default.id
  egress {
    protocol          = "ANY"
    description       = "any"
    v4_cidr_blocks    = ["0.0.0.0/0"]
  }
  ingress {
    protocol          = "Any"
    description       = "elastic"
    v4_cidr_blocks    = ["0.0.0.0/0"]
    port              = 9200-9210
  }
}

# Создание ВМ

resource "yandex_compute_instance" "web1" {
  name                = "web1"
  folder_id           = var.folder_id
  service_account_id  = yandex_iam_service_account.user.id
 
  resources {
    memory = 2
    cores  = 2
  }
  
  boot_disk {
    mode = "READ_WRITE"
    initialize_params {
      image_id = "fd87kbts7j40q5b9rpjr"
    }
  }

  network_interface {
    network_id = yandex_vpc_network.default.id
    subnet_ids = [
      yandex_vpc_subnet.private-net-b.id
    ]
    security_group_ids = [ yandex_vpc_security_group.slf.id, yandex_vpc_security_group.ssh.id, yandex_vpc_security_group.http.id, yandex_vpc_security_group.wb.id ]
  }

  metadata = {
    user-data = templatefile("config.tpl", {
      VM_USER = var.vm_user
      SSH_KEY = var.ssh_key
    })
  }

}

resource "yandex_compute_instance" "kibana" {
  name                = "kibana"
  folder_id           = var.folder_id
  service_account_id  = yandex_iam_service_account.user.id
 
  resources {
    memory = 2
    cores  = 2
  }
  
  boot_disk {
    mode = "READ_WRITE"
    initialize_params {
      image_id = "fd87kbts7j40q5b9rpjr"
    }
  }

  network_interface {
    network_id = yandex_vpc_network.default.id
    subnet_ids = [
      yandex_vpc_subnet.public-net-b.id
    ]
    security_group_ids = [ yandex_vpc_security_group.slf.id, yandex_vpc_security_group.ssh.id, yandex_vpc_security_group.kbn.id ]
  }

  metadata = {
    user-data = templatefile("config.tpl", {
      VM_USER = var.vm_user
      SSH_KEY = var.ssh_key
    })
  }

}

resource "yandex_compute_instance" "zabbix" {
  name                = "zabbix"
  folder_id           = var.folder_id
  service_account_id  = yandex_iam_service_account.user.id
 
  resources {
    memory = 2
    cores  = 2
  }
  
  boot_disk {
    mode = "READ_WRITE"
    initialize_params {
      image_id = "fd87kbts7j40q5b9rpjr"
    }
  }

  network_interface {
    network_id = yandex_vpc_network.default.id
    subnet_ids = [
      yandex_vpc_subnet.public-net-b.id
    ]
    security_group_ids = [ yandex_vpc_security_group.slf.id, yandex_vpc_security_group.ssh.id, yandex_vpc_security_group.http.id, yandex_vpc_security_group.zbx.id ]
  }

  metadata = {
    user-data = templatefile("config.tpl", {
      VM_USER = var.vm_user
      SSH_KEY = var.ssh_key
    })
  }

}

resource "yandex_compute_instance" "bastion-host" {
  name                = "bastion-host"
  folder_id           = var.folder_id
  service_account_id  = yandex_iam_service_account.user.id
 
  resources {
    memory = 2
    cores  = 2
  }
  
  boot_disk {
    mode = "READ_WRITE"
    initialize_params {
      image_id = "fd83omuuv0kssd0g5qt5"
    }
  }

  network_interface {
    network_id = yandex_vpc_network.default.id
    subnet_ids = [
      yandex_vpc_subnet.public-net-b.id
    ]
    security_group_ids = [ yandex_vpc_security_group.slf.id, yandex_vpc_security_group.ssh.id ]
  }

  metadata = {
    user-data = templatefile("config.tpl", {
      VM_USER = var.vm_user
      SSH_KEY = var.ssh_key
    })
  }

}

resource "yandex_compute_instance" "elasticsearch" {
  name                = "elasticsearch"
  folder_id           = var.folder_id
  service_account_id  = yandex_iam_service_account.user.id
 
  resources {
    memory = 2
    cores  = 2
  }
  
  boot_disk {
    mode = "READ_WRITE"
    initialize_params {
      image_id = "fd87kbts7j40q5b9rpjr"
    }
  }

  network_interface {
    network_id = yandex_vpc_network.default.id
    subnet_ids = [
      yandex_vpc_subnet.private-net-b.id
    ]
    security_group_ids = [ yandex_vpc_security_group.slf.id, yandex_vpc_security_group.ssh.id, yandex_vpc_security_group.els.id ]
  }

  metadata = {
    user-data = templatefile("config.tpl", {
      VM_USER = var.vm_user
      SSH_KEY = var.ssh_key
    })
  }

}

resource "yandex_compute_instance" "web2" {
  name                = "web2"
  folder_id           = var.folder_id
  service_account_id  = yandex_iam_service_account.user.id
 
  resources {
    memory = 2
    cores  = 2
  }
  
  boot_disk {
    mode = "READ_WRITE"
    initialize_params {
      image_id = "fd87kbts7j40q5b9rpjr"
    }
  }

  network_interface {
    network_id = yandex_vpc_network.default.id
    subnet_ids = [
      yandex_vpc_subnet.private-net-a.id
    ]
    security_group_ids = [ yandex_vpc_security_group.slf.id, yandex_vpc_security_group.ssh.id, yandex_vpc_security_group.http.id, yandex_vpc_security_group.wb.id ]
  }

  metadata = {
    user-data = templatefile("config.tpl", {
      VM_USER = var.vm_user
      SSH_KEY = var.ssh_key
    })
  }

}

# Создание целевой группы

resource "yandex_alb_target_group" "web-servers" {
  name           = "web-servers"

  target {
    subnet_id    = "yandex_vpc_subnet.private-net-a.id"
    ip_address   = "10.121.0.30"
  }

  target {
    subnet_id    = "yandex_vpc_subnet.private-net-b.id"
    ip_address   = "10.120.0.17"
  }

}
# Создание группы бэкендов

resource "yandex_alb_backend_group" "frontend" {
  name                     = "frontend"
 
  http_backend {
    name                   = "web1"
    weight                 = 1
    port                   = 80
    target_group_ids       = ["web-servers"]
    load_balancing_config {
      panic_threshold      = 90
    }
    enable_proxy_protocol  = true
  }
}

# Cоздание HTTP роутера

resource "yandex_alb_http_router" "for-web" {
  name          = "for-web"
}

resource "yandex_alb_virtual_host" "main" {
  name                    = "main"
  http_router_id          = yandex_alb_http_router.for-web.id
  route {
    name                  = "way-to-webserv"
    http_route {
      http_route_action {
        backend_group_id  = "yandex_alb_backend_group.frontend"
        timeout           = "60s"
      }
    }
  }
}

# Создание сетевого балансировщика

resource "yandex_lb_network_load_balancer" "balancer" {
  name = "frontend-webs"

  listener {
    name        = "http"
    port        = 80
    target_port = 80
  }

  attached_target_group {
    target_group_id = yandex_compute_instance_group.autoscale-group.load_balancer[0].target_group_id
    healthcheck {
      name = "tcp"
      tcp_options {
        port = 80
      }
    }
  }
}

# Создать политику

resource "yandex_backup_policy" "daily_backup-life_time_week" {
    compression                       = "NORMAL"
    fast_backup_enabled               = true
    format                            = "AUTO"
    multi_volume_snapshotting_enabled = true
    name                              = "daily_backup-life_time_week"
    performance_window_enabled        = true
    silent_mode_enabled               = true
    splitting_bytes                   = "9223372036854775807"

    reattempts {
        enabled      = true
        interval     = "1m"
        max_attempts = 10
    }

    retention {
        after_backup = false

        rules {
            max_age       = "7d"
            repeat_period = []
        }
    }

    scheduling {
        enabled              = false
        max_parallel_backups = 0
        random_max_delay     = "30m"
        scheme               = "ALWAYS_INCREMENTAL"

        execute_by_interval {
            repeat_at                 = ["04:10"]
            type                      = "DAILY"
        }
    }

    vm_snapshot_reattempts {
        enabled      = true
        interval     = "1m"
        max_attempts = 10
    }
} 
