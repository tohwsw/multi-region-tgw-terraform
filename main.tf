terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.36"
    }
  }
}

provider "aws" {
  alias  = "aws_sg"
  region = "ap-southeast-1"
}

provider "aws" {
  alias  = "aws_us"
  region = "us-east-1"
}

provider "aws" {
  alias  = "aws_eu"
  region = "eu-west-1"
}

data "aws_region" "peer_sg" {
  provider = aws.aws_sg
}

data "aws_region" "peer_eu" {
  provider = aws.aws_eu
}

data "aws_vpcs" "sg_vpcs" {
  provider = aws.aws_sg
  tags = {
    Name = "eks*"
  }
}

data "aws_vpcs" "eu_vpcs" {
  provider = aws.aws_eu
  tags = {
    Name = "eks*"
  }
}

data "aws_vpcs" "us_vpcs" {
  provider = aws.aws_us
  tags = {
    Name = "eks*"
  }
}

data "aws_vpc" "sg_vpc" {
  provider = aws.aws_sg
  id = tolist(data.aws_vpcs.sg_vpcs.ids)[0]
}

data "aws_vpc" "eu_vpc" {
  provider = aws.aws_eu
  id = tolist(data.aws_vpcs.eu_vpcs.ids)[0]
}

data "aws_vpc" "us_vpc" {
  provider = aws.aws_us
  id = tolist(data.aws_vpcs.us_vpcs.ids)[0]
}

data "aws_route_table" "sg_private_routetable" {
  provider = aws.aws_sg
  tags = {
    Name = "*private*"
  }
}

data "aws_route_table" "eu_private_routetable" {
  provider = aws.aws_eu
  tags = {
    Name = "*private"
  }
}

data "aws_route_table" "us_private_routetable" {
  provider = aws.aws_us
  tags = {
    Name = "*private"
  }
}

# A provider block without an alias argument is the default configuration for that provider
provider "aws" {
  region = "ap-southeast-1"
}

resource "aws_ec2_transit_gateway" "tgw_sg" {
  auto_accept_shared_attachments = "enable"
  tags = {
    Name = "EKS TGW"
  }
}

resource "aws_ec2_transit_gateway" "tgw_us" {
  provider = aws.aws_us
  auto_accept_shared_attachments = "enable"
  tags = {
    Name = "EKS TGW"
  }
}

resource "aws_ec2_transit_gateway" "tgw_eu" {
  provider = aws.aws_eu
  auto_accept_shared_attachments = "enable"
  tags = {
    Name = "EKS TGW"
  }
}

resource "aws_ec2_transit_gateway_peering_attachment" "sg_eu" {
  provider = aws.aws_eu
  peer_account_id         = aws_ec2_transit_gateway.tgw_sg.owner_id
  peer_region             = data.aws_region.peer_sg.name
  peer_transit_gateway_id = aws_ec2_transit_gateway.tgw_sg.id
  transit_gateway_id      = aws_ec2_transit_gateway.tgw_eu.id

  tags = {
    Name = "TGW Peering Requestor"
  }

}

resource "aws_ec2_transit_gateway_peering_attachment" "sg_us" {
  provider = aws.aws_us
  peer_account_id         = aws_ec2_transit_gateway.tgw_sg.owner_id
  peer_region             = data.aws_region.peer_sg.name
  peer_transit_gateway_id = aws_ec2_transit_gateway.tgw_sg.id
  transit_gateway_id      = aws_ec2_transit_gateway.tgw_us.id

  tags = {
    Name = "TGW Peering Requestor"
  }
}

resource "aws_ec2_transit_gateway_peering_attachment" "eu_us" {
  provider = aws.aws_us
  peer_account_id         = aws_ec2_transit_gateway.tgw_eu.owner_id
  peer_region             = data.aws_region.peer_eu.name
  peer_transit_gateway_id = aws_ec2_transit_gateway.tgw_eu.id
  transit_gateway_id      = aws_ec2_transit_gateway.tgw_us.id

  tags = {
    Name = "TGW Peering Requestor"
  }
}

# Accept the peering attachment request from the Region that the accepter transit gateway is located in
resource "aws_ec2_transit_gateway_peering_attachment_accepter" "sg_us" {
  transit_gateway_attachment_id = aws_ec2_transit_gateway_peering_attachment.sg_us.id

  tags = {
    Name = "Example cross-account attachment"
  }
}

resource "aws_ec2_transit_gateway_peering_attachment_accepter" "sg_eu" {
  transit_gateway_attachment_id = aws_ec2_transit_gateway_peering_attachment.sg_eu.id

  tags = {
    Name = "Example cross-account attachment"
  }
}

# us_eu peering attachment has to be manually accepted

# Create the routes in VPC private subnet route tables

resource "aws_route" "sg_eu_route" {
  provider = aws.aws_sg
  route_table_id            = data.aws_route_table.sg_private_routetable.id
  destination_cidr_block    = data.aws_vpc.eu_vpc.cidr_block
  transit_gateway_id = aws_ec2_transit_gateway.tgw_sg.id
}

resource "aws_route" "sg_us_route" {
  provider = aws.aws_sg
  route_table_id            = data.aws_route_table.sg_private_routetable.id
  destination_cidr_block    = data.aws_vpc.us_vpc.cidr_block
  transit_gateway_id = aws_ec2_transit_gateway.tgw_sg.id
}

resource "aws_route" "eu_sg_route" {
  provider = aws.aws_eu
  route_table_id            = data.aws_route_table.eu_private_routetable.id
  destination_cidr_block    = data.aws_vpc.sg_vpc.cidr_block
  transit_gateway_id = aws_ec2_transit_gateway.tgw_eu.id
}

resource "aws_route" "eu_us_route" {
  provider = aws.aws_eu
  route_table_id            = data.aws_route_table.eu_private_routetable.id
  destination_cidr_block    = data.aws_vpc.us_vpc.cidr_block
  transit_gateway_id = aws_ec2_transit_gateway.tgw_eu.id
}

resource "aws_route" "us_sg_route" {
  provider = aws.aws_us
  route_table_id            = data.aws_route_table.us_private_routetable.id
  destination_cidr_block    = data.aws_vpc.sg_vpc.cidr_block
  transit_gateway_id = aws_ec2_transit_gateway.tgw_us.id
}

resource "aws_route" "us_eu_route" {
  provider = aws.aws_us
  route_table_id            = data.aws_route_table.us_private_routetable.id
  destination_cidr_block    = data.aws_vpc.eu_vpc.cidr_block
  transit_gateway_id = aws_ec2_transit_gateway.tgw_us.id
}

