variable "aws_region" {
  description = "Region to deploy into. Pick one close to you; AMI lookup below is region-agnostic."
  type        = string
  default     = "eu-central-1"
}

variable "name" {
  description = "Name applied to the instance, key pair, security group and EIP. Change this and everything is namespaced consistently."
  type        = string
  default     = "workstation"
}

variable "instance_type" {
  description = <<-EOT
    2 vCPU / 4 GB is the practical floor for an agent plus dev work; go to
    t3.large (8 GB) if a real browser (Firefox/Chromium) will run on the box.
    t3.micro (1 GB) will boot and then get OOM-killed under load.

    NOTE: AWS's post-2025 "Free plan" refuses larger types with
    FreeTierRestrictionError until the account upgrades to the Paid plan.
    Resizing later is a one-line change plus a stop/start; the root volume
    and everything on it survives.
  EOT
  type        = string
  default     = "t3.medium"
}

variable "root_volume_size" {
  description = "Root disk (GB). Repos, Docker images and node_modules add up fast. Growing later works without replacing the instance, but needs an in-guest filesystem resize (see README), so starting bigger is cheaper in effort."
  type        = number
  default     = 50
}

variable "swap_size_mb" {
  description = "Swapfile size, created by cloud-init. Converts an OOM kill into mere slowness. Heavy swap use means buy RAM instead; this is headroom, not a fix."
  type        = number
  default     = 4096
}

variable "ssh_public_key" {
  description = "Contents of your SSH public key, e.g. file(\"~/.ssh/workstation.pub\"). Generate with: ssh-keygen -t ed25519 -f ~/.ssh/workstation"
  type        = string
}

variable "allowed_ssh_cidrs" {
  description = "Who may reach port 22. Defaults open because you rarely know your source IP up front; tighten to \"$(curl -s ifconfig.me)/32\" once you do. A security group is a stateful firewall attached to the instance — replies to outbound traffic are allowed back automatically, so only inbound rules are needed."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "extra_ingress_ports" {
  description = "Additional inbound TCP ports. Leave EMPTY unless you know why. Anything an agent serves (dashboards, APIs) holds credentials and should be reached over the mesh VPN or an SSH tunnel, not opened here."
  type        = list(number)
  default     = []
}
