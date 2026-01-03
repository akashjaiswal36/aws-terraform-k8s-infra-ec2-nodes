resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  
  tags = {
    Name = "k8s-vpc-${terraform.workspace}"
  }
}

resource "aws_subnet" "main" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "k8s-subnet-${terraform.workspace}"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "k8s-igw-${terraform.workspace}"
  }
}

resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "k8s-rt-${terraform.workspace}"
  }
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.main.id 
  route_table_id = aws_route_table.rt.id
}


# Control Plane SG
resource "aws_security_group" "k8s_control_plane_sg" {
  name        = "k8s-control-plane-sg"
  description = "Security group for Kubernetes control plane"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "k8s-control-plane-sg-${terraform.workspace}"
  }
}

# Worker Nodes SG
resource "aws_security_group" "k8s_nodes_sg" {
  name        = "k8s-nodes-sg"
  description = "Security group for Kubernetes worker nodes"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "k8s-nodes-sg-${terraform.workspace}"
  }
}

# -------------------------
# Control Plane Rules
# -------------------------


# Kubernetes API server (external)
resource "aws_security_group_rule" "cp_api_server" {
  type              = "ingress"
  from_port         = 6443
  to_port           = 6443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.k8s_control_plane_sg.id
}

resource "aws_security_group_rule" "ssh_server" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.k8s_control_plane_sg.id
}

# etcd access from workers
resource "aws_security_group_rule" "cp_etcd_from_workers" {
  type                     = "ingress"
  from_port                = 2379
  to_port                  = 2380
  protocol                 = "tcp"
  cidr_blocks              = ["10.0.0.0/16"]
  security_group_id        = aws_security_group.k8s_control_plane_sg.id
}

resource "aws_security_group_rule" "controlplane_kubelet" {
  type              = "ingress"
  from_port         = 10250
  to_port           = 10250
  protocol          = "tcp"
  cidr_blocks       = ["10.0.0.0/16"] # replace with your VPC CIDR
  security_group_id = aws_security_group.k8s_control_plane_sg.id
}

resource "aws_security_group_rule" "kube_scheduler" {
  type              = "ingress"
  from_port         = 10259
  to_port           = 10259
  protocol          = "tcp"
  cidr_blocks       = ["10.0.0.0/16"] # replace with your VPC CIDR
  security_group_id = aws_security_group.k8s_control_plane_sg.id
}

resource "aws_security_group_rule" "kube_controller" {
  type              = "ingress"
  from_port         = 10257
  to_port           = 10257
  protocol          = "tcp"
  cidr_blocks       = ["10.0.0.0/16"] # replace with your VPC CIDR
  security_group_id = aws_security_group.k8s_control_plane_sg.id
}

# VXLAN overlay (self)
resource "aws_security_group_rule" "cp_vxlan_self" {
  type                     = "ingress"
  from_port                = 8472
  to_port                  = 8472
  protocol                 = "udp"
  source_security_group_id = aws_security_group.k8s_control_plane_sg.id
  security_group_id        = aws_security_group.k8s_control_plane_sg.id
}

# VXLAN overlay (workers)
resource "aws_security_group_rule" "cp_vxlan_workers" {
  type                     = "ingress"
  from_port                = 8472
  to_port                  = 8472
  protocol                 = "udp"
  source_security_group_id = aws_security_group.k8s_nodes_sg.id
  security_group_id        = aws_security_group.k8s_control_plane_sg.id
}

# Health checks (self)
resource "aws_security_group_rule" "cp_health_self" {
  type                     = "ingress"
  from_port                = 4240
  to_port                  = 4240
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.k8s_control_plane_sg.id
  security_group_id        = aws_security_group.k8s_control_plane_sg.id
}

# Health checks (workers)
resource "aws_security_group_rule" "cp_health_workers" {
  type                     = "ingress"
  from_port                = 4240
  to_port                  = 4240
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.k8s_nodes_sg.id
  security_group_id        = aws_security_group.k8s_control_plane_sg.id
}

# ICMP echo request (self)
resource "aws_security_group_rule" "cp_icmp_self" {
  type                     = "ingress"
  from_port                = 8
  to_port                  = 0
  protocol                 = "icmp"
  source_security_group_id = aws_security_group.k8s_control_plane_sg.id
  security_group_id        = aws_security_group.k8s_control_plane_sg.id
}

# ICMP echo request (workers)
resource "aws_security_group_rule" "cp_icmp_workers" {
  type                     = "ingress"
  from_port                = 8
  to_port                  = 0
  protocol                 = "icmp"
  source_security_group_id = aws_security_group.k8s_nodes_sg.id
  security_group_id        = aws_security_group.k8s_control_plane_sg.id
}

# Allow all egress from control plane
resource "aws_security_group_rule" "cp_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.k8s_control_plane_sg.id
}

# -------------------------
# Worker Node Rules
# -------------------------

# Kubelet API (internal only)
resource "aws_security_group_rule" "nodes_kubelet" {
  type              = "ingress"
  from_port         = 10250
  to_port           = 10250
  protocol          = "tcp"
  cidr_blocks       = ["10.0.0.0/16"] # replace with your VPC CIDR
  security_group_id = aws_security_group.k8s_nodes_sg.id
}

# kube-proxy (internal only)
resource "aws_security_group_rule" "nodes_kube_proxy" {
  type              = "ingress"
  from_port         = 10256
  to_port           = 10256
  protocol          = "tcp"
  cidr_blocks       = ["10.0.0.0/16"]
  security_group_id = aws_security_group.k8s_nodes_sg.id
}

resource "aws_security_group_rule" "ssh_instances" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.k8s_nodes_sg.id
}

# NodePort Services (TCP)
resource "aws_security_group_rule" "nodes_nodeport_tcp" {
  type              = "ingress"
  from_port         = 30000
  to_port           = 32767
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"] # or restrict to trusted IPs
  security_group_id = aws_security_group.k8s_nodes_sg.id
}

# NodePort Services (UDP)
resource "aws_security_group_rule" "nodes_nodeport_udp" {
  type              = "ingress"
  from_port         = 30000
  to_port           = 32767
  protocol          = "udp"
  cidr_blocks       = ["0.0.0.0/0"] # or restrict to trusted IPs
  security_group_id = aws_security_group.k8s_nodes_sg.id
}

# VXLAN overlay from masters
resource "aws_security_group_rule" "nodes_vxlan_masters" {
  type                     = "ingress"
  from_port                = 8472
  to_port                  = 8472
  protocol                 = "udp"
  source_security_group_id = aws_security_group.k8s_control_plane_sg.id
  security_group_id        = aws_security_group.k8s_nodes_sg.id
}

# VXLAN overlay worker-to-worker
resource "aws_security_group_rule" "nodes_vxlan_self" {
  type                     = "ingress"
  from_port                = 8472
  to_port                  = 8472
  protocol                 = "udp"
  source_security_group_id = aws_security_group.k8s_nodes_sg.id
  security_group_id        = aws_security_group.k8s_nodes_sg.id
}

# Health checks from masters
resource "aws_security_group_rule" "nodes_health_masters" {
  type                     = "ingress"
  from_port                = 4240
  to_port                  = 4240
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.k8s_control_plane_sg.id
  security_group_id        = aws_security_group.k8s_nodes_sg.id
}

# Health checks worker-to-worker
resource "aws_security_group_rule" "nodes_health_self" {
  type                     = "ingress"
  from_port                = 4240
  to_port                  = 4240
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.k8s_nodes_sg.id
  security_group_id        = aws_security_group.k8s_nodes_sg.id
}

# ICMP health checks from masters
resource "aws_security_group_rule" "nodes_icmp_masters" {
  type                     = "ingress"
  from_port                = 8
  to_port                  = 0
  protocol                 = "icmp"
  source_security_group_id = aws_security_group.k8s_control_plane_sg.id
  security_group_id        = aws_security_group.k8s_nodes_sg.id
}

# ICMP health checks worker-to-worker
resource "aws_security_group_rule" "nodes_icmp_self" {
  type                     = "ingress"
  from_port                = 8
  to_port                  = 0
  protocol                 = "icmp"
  source_security_group_id = aws_security_group.k8s_nodes_sg.id
  security_group_id        = aws_security_group.k8s_nodes_sg.id
}

# Allow all egress from workers
resource "aws_security_group_rule" "nodes_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.k8s_nodes_sg.id
}


resource "aws_instance" "controlplan" {
  ami           = "ami-02b8269d5e85954ef"
  instance_market_options {
    market_type = "spot"
  }
  key_name      = var.key_name
  instance_type = var.instance_type

  vpc_security_group_ids = [aws_security_group.k8s_control_plane_sg.id]
  subnet_id = aws_subnet.main.id

  user_data = file("${path.module}/controlplane.sh")

  tags = {
    Name = "controlplane-${terraform.workspace}"
  }
}

resource "aws_instance" "workernodes" {
  depends_on = [aws_instance.controlplan]
  count = 2
  ami           = "ami-02b8269d5e85954ef"
  instance_market_options {
    market_type = "spot"
  }
  key_name      = var.key_name
  instance_type = var.instance_type

  vpc_security_group_ids = [aws_security_group.k8s_nodes_sg.id]
  subnet_id = aws_subnet.main.id

  user_data = file("${path.module}/worker-nodes.sh")

  tags = {
    Name = "workernode-${count.index}-${terraform.workspace}"
  }
}

