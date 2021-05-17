provider "aws" {
   region = "ap-south-1"
   alias = "west"
}

#Create a VPC
resource "aws_vpc" "tomcatvpc" {
    cidr_block = "10.0.0.0/16"  

    tags = {
      "name" = "WEBAPP VPC"
    }
}

#create internet gateway
resource "aws_internet_gateway" "tomcatgw" {
  vpc_id = aws_vpc.tomcatvpc.id 

  tags = {
    Name = "Webapp gateway"
  }
}
#create custom route table
resource "aws_route_table" "tomcatrt" {
  vpc_id = aws_vpc.tomcatvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.tomcatgw.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.tomcatgw.id
  }

  tags = {
    Name = "Webapp route table"
  }
}
#create a subnet
resource "aws_subnet" "tomcatsu" {
    vpc_id = aws_vpc.tomcatvpc.id
    cidr_block = "10.0.1.0/24"
    availability_zone = "ap-south-1a"
    tags = {
      "name" = "Web App subnet"
    }
}

#associate the subnet to route table
resource "aws_route_table_association" "tomcatstr" {
  subnet_id      = aws_subnet.tomcatsu.id
  route_table_id = aws_route_table.tomcatrt.id
}
#create Security Groups to allow ports for ssh, http, https traffic
resource "aws_security_group" "tomcatsg" {
  name        = "Webapp_tls"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.tomcatvpc.id

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
    from_port        = 8080
    to_port          = 8080
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
resource "aws_network_interface" "tomcatnic" {
  subnet_id       = aws_subnet.tomcatsu.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.tomcatsg.id]
}
#create a elastic ip
resource "aws_eip" "tomcatip" {
  vpc                       = true
  network_interface         = aws_network_interface.tomcatnic.id
  associate_with_private_ip = "10.0.1.50"
  depends_on = [aws_internet_gateway.tomcatgw]
}       

#create a ubuntu server and install tomcat server
resource "aws_instance" "TomcatServer" {
    ami = "ami-010aff33ed5991201"
    instance_type = "t2.micro"
    availability_zone = "ap-south-1a"
    key_name = "Webserverkey"
    
    network_interface {
      device_index =0
      network_interface_id = aws_network_interface.tomcatnic.id

    }

    tags = {
      "Name" = "Tomcat Server"
    }
    user_data = <<EOF
                cd /opt
                sudo wget http://mirrors.fibergrid.in/apache/tomcat/tomcat-8/v8.5.35/bin/apache-tomcat-8.5.35.tar.gz
                sudo tar -xvzf /opt/apache-tomcat-8.5.35.tar.gz 
                chmod +x /opt/apache-tomcat-8.5.35/bin/startup.sh
                chmod +x /opt/apache-tomcat-8.5.35/bin/shutdown.sh
                sudo ln -s /opt/apache-tomcat-8.5.35/bin/startup.sh /usr/local/bin/tomcatup
                sudo ln -s /opt/apache-tomcat-8.5.35/bin/shutdown.sh /usr/local/bin/tomcatdown
                EOF
            
}