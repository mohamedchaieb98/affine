data "aws_vpc" "vpc_affine" {
  filter {
    name   = "tag:name"
    values = ["vpc-datiumsas-apps"]
  }
}

data "aws_subnets" "public_subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.vpc_affine.id]
  }
  filter {
    name   = "map-public-ip-on-launch"
    values = ["true"]
  }
}


data "aws_subnets" "private_subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.vpc_affine.id]
  }
  filter {
    name   = "map-public-ip-on-launch"
    values = ["false"]
  }
}