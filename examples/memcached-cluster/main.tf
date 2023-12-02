provider "aws" {
  region = local.region
}

data "aws_availability_zones" "available" {}

locals {
  region = "us-east-1"
  name   = "ex-${basename(path.cwd)}"

  vpc_cidr = "10.0.0.0/16"
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)

  tags = {
    Name       = local.name
    Example    = local.name
    Repository = "https://github.com/clowdhaus/terraform-aws-elasticache"
  }
}

################################################################################
# ElastiCache Module
################################################################################

module "elasticache" {
  source = "../../"

  cluster_id               = local.name
  create_cluster           = true
  create_replication_group = false

  engine          = "memcached"
  engine_version  = "1.6.17"
  node_type       = "cache.t4g.small"
  num_cache_nodes = 2
  az_mode         = "cross-az"

  # Security group
  vpc_id = module.vpc.vpc_id
  security_group_rules = {
    ingress_vpc = {
      # Default type is `ingress`
      # Default port is based on the default engine port
      description = "VPC traffic"
      cidr_ipv4   = module.vpc.vpc_cidr_block
    }
  }

  # subnet group
  subnet_group_name        = local.name
  subnet_group_description = "${title(local.name)} subnet group"
  subnet_ids               = module.vpc.private_subnets

  maintenance_window = "sun:05:00-sun:09:00"
  apply_immediately  = true

  # parameter group
  create_parameter_group      = true
  parameter_group_name        = local.name
  parameter_group_family      = "memcached1.6"
  parameter_group_description = "${title(local.name)} parameter group"
  parameters = [
    {
      name  = "idle_timeout"
      value = 60
    }
  ]

  tags = local.tags
}


module "elasticache_disabled" {
  source = "../.."

  create = false
}

################################################################################
# Supporting Resources
################################################################################

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = local.name
  cidr = local.vpc_cidr

  azs             = local.azs
  public_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k)]
  private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 10)]

  tags = local.tags
}
