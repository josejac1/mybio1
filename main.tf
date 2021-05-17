provider "aws" {
   region = "ap-south-1"
}

#Create a VPC
resource "aws_vpc" "Webappvpc" {
    cidr_block = "10.0.0.0/16"  

    tags = {
      "name" = "WEBAPP VPC"
    }
}

#create internet gateway
resource "aws_internet_gateway" "Webappgw" {
  vpc_id = aws_vpc.Webappvpc.id 

  tags = {
    Name = "Webapp gateway"
  }
}
#create custom route table
resource "aws_route_table" "Webapprt" {
  vpc_id = aws_vpc.Webappvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.Webappgw.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.Webappgw.id
  }

  tags = {
    Name = "Webapp route table"
  }
}
#create a subnet
resource "aws_subnet" "Webappsu" {
    vpc_id = aws_vpc.Webappvpc.id
    cidr_block = "10.0.1.0/24"
    availability_zone = "ap-south-1a"
    tags = {
      "name" = "Web App subnet"
    }
}

#associate the subnet to route table
resource "aws_route_table_association" "Webappstr" {
  subnet_id      = aws_subnet.Webappsu.id
  route_table_id = aws_route_table.Webapprt.id
}
#create Security Groups to allow ports for ssh, http, https traffic
resource "aws_security_group" "Webappsg" {
  name        = "Webapp_tls"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.Webappvpc.id

  ingress {
    description      = "HTTPS from VPC"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    #ipv6_cidr_blocks = [aws_vpc.main.ipv6_cidr_block]
  }
  ingress {
    description      = "HTTP from VPC"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    #ipv6_cidr_blocks = [aws_vpc.main.ipv6_cidr_block]
  }
  ingress {
    description      = "HTTPS from VPC"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    #ipv6_cidr_blocks = [aws_vpc.main.ipv6_cidr_block]
  }


  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_tls"
  }
}
#create a network interface
resource "aws_network_interface" "Webappnic" {
  subnet_id       = aws_subnet.Webappsu.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.Webappsg.id]
}
#create a elastic ip
resource "aws_eip" "Webappeip" {
  vpc                       = true
  network_interface         = aws_network_interface.Webappnic.id
  associate_with_private_ip = "10.0.1.50"
  depends_on = [aws_internet_gateway.Webappgw]
}       

#create a ubuntu server and install tomcat server
resource "aws_instance" "JenkinsServer" {
    ami = "ami-010aff33ed5991201"
    instance_type = "t2.micro"
    availability_zone = "ap-south-1a"
    key_name = "Webserverkey"
    
    network_interface {
      device_index =0
      network_interface_id = aws_network_interface.Webappnic.id

    }

    tags = {
      "Name" = "Jenkins Server"
    }
    user_data = <<EOF
                yum install java-1.8*
                java -version
                EOF
            
}