# --- Network: reuse the account's default VPC -----------------------------
# Every region gets a default VPC with a public subnet per AZ at account
# creation. A hand-built VPC (private subnets, NAT gateway, route tables) buys
# nothing for a single internet-facing box and costs a NAT gateway per month.
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# --- AMI: latest Ubuntu 22.04 LTS from Canonical --------------------------
# AMI IDs are region-specific for the same image, so look it up rather than
# hardcoding. Swap "jammy-22.04" for "noble-24.04" if you want the newer LTS.
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_key_pair" "admin" {
  key_name   = var.name
  public_key = var.ssh_public_key
}

# --- Security group -------------------------------------------------------
resource "aws_security_group" "workstation" {
  name        = "${var.name}-sg"
  description = "SSH in; all outbound (package mirrors, LLM APIs, mesh VPN)"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidrs
  }

  # Everything else the box serves is reached over the mesh VPN (which needs
  # no inbound rule — it is an outbound connection to the coordination server)
  # or an SSH tunnel. This closed-by-default posture is what makes it safe to
  # bind a dashboard to 0.0.0.0 inside the instance.
  dynamic "ingress" {
    for_each = var.extra_ingress_ports
    content {
      description = "extra port ${ingress.value}"
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = var.allowed_ssh_cidrs
    }
  }

  egress {
    description = "all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "workstation" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.admin.key_name
  subnet_id                   = data.aws_subnets.default.ids[0]
  vpc_security_group_ids      = [aws_security_group.workstation.id]
  associate_public_ip_address = true

  user_data = templatefile("${path.module}/cloud-init.yaml", {
    swap_size_mb = var.swap_size_mb
  })

  # Re-running user_data on change would recreate the instance and destroy the
  # disk. cloud-init is first-boot bootstrap only; later changes go through
  # the provisioning steps in references/provisioning.md.
  user_data_replace_on_change = false

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = "gp3"
    delete_on_termination = true
  }

  tags = { Name = var.name }

  lifecycle {
    # The AMI data source returns a newer ID whenever Canonical publishes one;
    # without this, an unrelated `apply` would silently rebuild the box.
    ignore_changes = [ami]
  }
}

# --- Elastic IP -----------------------------------------------------------
# An instance-type change requires a stop/start, which swaps an auto-assigned
# public IP for a different one — breaking known_hosts and every saved client
# config. AWS bills for any public IPv4 since 2024, so an EIP costs the same
# and is stable. Attached EIPs are not charged extra; UNATTACHED ones are.
resource "aws_eip" "workstation" {
  instance = aws_instance.workstation.id
  domain   = "vpc"
  tags     = { Name = var.name }
}
