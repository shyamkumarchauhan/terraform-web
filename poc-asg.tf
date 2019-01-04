data "aws_availability_zones" "available" {}
### Creating Developer IAM Users
resource "aws_iam_user" "developer" {
 count = "${length(var.username)}" 
 name = "${element(var.username,count.index )}" 
}
### Create Policy Document
data "aws_iam_policy_document" "web-server-restart" {
  statement {
    actions = [
      "ec2:RebootInstances"]
    resources = [
            "arn:aws:ec2:us-east-2:146254080149:instance/*",
            "arn:aws:ec2:us-east-2:146254080149:key-pair/terraform"
            ]
  }
  statement {
    actions = [
      "ec2:DescribeTags", 
      "ec2:DescribeInstances"]
    resources = [
            "*",
            ]
}
}
### Creating Policy for IAM User
resource "aws_iam_policy" "web-server-restart-policy" {
 name = "web-server-restart-policy"
 policy = "${data.aws_iam_policy_document.web-server-restart.json}"
}
### Attach Policy to IAM USer
resource "aws_iam_user_policy_attachment" "web-server-restart-attach" {
 count = "${length(var.username)}"
 user = "${element(aws_iam_user.developer.*.name,count.index )}" 
 policy_arn = "${aws_iam_policy.web-server-restart-policy.arn}"
}
### Creating VPC
resource "aws_vpc" "terraform-zantac-vpc" {
  cidr_block = "10.0.0.0/16"
  instance_tenancy = "default"
  enable_dns_support = "true"
  enable_dns_hostnames = "true"
  enable_classiclink = "false"
tags {
  Name = "terraform-zantac"
}
}
resource "aws_subnet" "public1-zantac" {
  vpc_id = "${aws_vpc.terraform-zantac-vpc.id}"
  cidr_block ="10.0.1.0/24"
  map_public_ip_on_launch = "true"
  availability_zone = "${data.aws_availability_zones.available.names[0]}" 
tags {
  Name = "public1-zantac"
}
}
resource "aws_subnet" "public2-zantac" {
  vpc_id = "${aws_vpc.terraform-zantac-vpc.id}"
  cidr_block ="10.0.2.0/24"
  map_public_ip_on_launch = "true"
  availability_zone = "${data.aws_availability_zones.available.names[1]}"
tags {
  Name = "public2-zantac"
}
}
resource "aws_internet_gateway" "gw" {
  vpc_id = "${aws_vpc.terraform-zantac-vpc.id}"
tags {
  Name = "internet-gateway"
}
}
resource "aws_route_table" "rt1"{
  vpc_id = "${aws_vpc.terraform-zantac-vpc.id}"
    route {
      cidr_block = "0.0.0.0/0"
      gateway_id = "${aws_internet_gateway.gw.id}"
}
tags {
  Name = "Default"
}
}
resource "aws_route_table_association" "association1-subnet" {
  subnet_id ="${aws_subnet.public1-zantac.id}"
  route_table_id = "${aws_route_table.rt1.id}"
}
resource "aws_route_table_association" "association2-subnet" {
  subnet_id ="${aws_subnet.public2-zantac.id}"
  route_table_id = "${aws_route_table.rt1.id}"
}
### Creating EC2 instance
resource "aws_instance" "web" {
  ami               = "${lookup(var.amis,var.region)}"
  count             = "${var.count}"
  key_name               = "${var.key_name}"
  vpc_security_group_ids = ["${aws_security_group.zantac-sg.id}"]
  subnet_id = "${aws_subnet.public1-zantac.id}"
  source_dest_check = false
  instance_type = "t2.micro"
tags {
    Name = "${format("web-%03d", count.index + 1)}"
  }
}
### Creating Security Group for EC2
resource "aws_security_group" "zantac-sg" {
  name = "terraform-zantac-sg"
  vpc_id = "${aws_vpc.terraform-zantac-vpc.id}"
  ingress {
    from_port = 8080
    to_port = 8080
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
## Creating Launch Configuration
resource "aws_launch_configuration" "zantac-lc" {
  image_id               = "${lookup(var.amis,var.region)}"
  instance_type          = "t2.micro"
  security_groups        = ["${aws_security_group.zantac-sg.id}"]
  key_name               = "${var.key_name}"
  user_data = <<-EOF
              #!/bin/bash
              echo "Welcome to Zantac PoC" > index.html
              echo "My hostname is : $(hostname)" > index.html
              nohup busybox httpd -f -p 8080 &
              EOF
  lifecycle {
    create_before_destroy = true
  }
}
## Creating AutoScaling Group
resource "aws_autoscaling_group" "zantac-asg" {
  launch_configuration = "${aws_launch_configuration.zantac-lc.id}"
  #availability_zones = ["${data.aws_availability_zones.available.names[0]}","${data.aws_availability_zones.available.names[1]}"]
  vpc_zone_identifier = ["${aws_subnet.public1-zantac.id}","${aws_subnet.public2-zantac.id}"]
  min_size = 3
  max_size = 10
  load_balancers = ["${aws_elb.zantac-elb.name}"]
  health_check_type = "ELB"
  tag {
    key = "Name"
    value = "terraform-zantac-asg"
    propagate_at_launch = true
  }
}
## Security Group for ELB
resource "aws_security_group" "elb-sg" {
  name = "terraform-zantac-elb-sg"
  vpc_id = "${aws_vpc.terraform-zantac-vpc.id}"
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
### Creating ELB
resource "aws_elb" "zantac-elb" {
  name = "terraform-asg-zantac-elb"
  security_groups = ["${aws_security_group.elb-sg.id}"]
  #availability_zones = ["${data.aws_availability_zones.all.names}"]
  subnets = ["${aws_subnet.public1-zantac.id}","${aws_subnet.public2-zantac.id}"]
  health_check {
    healthy_threshold = 2
    unhealthy_threshold = 2
    timeout = 3
    interval = 30
    target = "HTTP:8080/"
  }
  listener {
    lb_port = 80
    lb_protocol = "http"
    instance_port = "8080"
    instance_protocol = "http"
  }
}
