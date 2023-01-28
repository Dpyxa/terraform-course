resource "aws_vpc" "ail_vpc" {
  cidr_block           = "10.123.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "test_ail"
  }
}

resource "aws_subnet" "ail_pulic_subnet" {
  vpc_id                  = aws_vpc.ail_vpc.id
  cidr_block              = "10.123.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "eu-west-1a"

  tags = {
    Name = "test_ail_public"
  }
}

resource "aws_internet_gateway" "ail_internet_gateway" {
  vpc_id = aws_vpc.ail_vpc.id

  tags = {
    Name = "test_ail_igw"
  }
}

resource "aws_route_table" "ail_public_rt" {
  vpc_id = aws_vpc.ail_vpc.id

  tags = {
    Name = "test_ail_public_rt"
  }
}

resource "aws_route" "default_route" {
  route_table_id         = aws_route_table.ail_public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.ail_internet_gateway.id
}

resource "aws_route_table_association" "ail_public_assoc" {
  subnet_id      = aws_subnet.ail_pulic_subnet.id
  route_table_id = aws_route_table.ail_public_rt.id
}

resource "aws_security_group" "ail_sg" {
  name        = "ail_allow_tls"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.ail_vpc.id

  ingress {
    description = "TLS from VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["193.254.221.24/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ail_test_sg"
  }
}

resource "aws_key_pair" "ail_auth" {
  key_name   = "ailkey"
  public_key = file("~/.ssh/ailkey.pub")
}

resource "aws_instance" "dev_node" {
  instance_type          = "t2.micro"
  ami                    = data.aws_ami.ail_ami.id
  key_name               = aws_key_pair.ail_auth.id
  vpc_security_group_ids = [aws_security_group.ail_sg.id]
  subnet_id              = aws_subnet.ail_pulic_subnet.id
  user_data              = file("userdata.tpl")

  tags = {
    name = "dev-node"
  }

  provisioner "local-exec" {
    command = templatefile("${var.host_os}-ssh-config.tpl", {
      hostname     = self.public_ip,
      user         = "ubuntu",
      identityfile = "~/.ssh/ailkey"
    })
    interpreter = var.host_os == "mac" ? ["bash", "-c"] : ["powershell", "-commanda"]
  }

}