terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
}
##### VPC CONFIGURATION

resource "aws_vpc" "a5_vpc" {
  cidr_block = "10.0.0.0/16"
}
resource "aws_subnet" "a5_subnet" {
  vpc_id     = aws_vpc.a5_vpc.id
  cidr_block = "10.0.101.0/24"
}
resource "aws_internet_gateway" "a5_gw" {
  vpc_id = aws_vpc.a5_vpc.id
}
resource "aws_route_table" "a5_route_table" {
  vpc_id = aws_vpc.a5_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.a5_gw.id
  }
}
resource "aws_route_table_association" "a5_table_association" {
  subnet_id      = aws_subnet.a5_subnet.id
  route_table_id = aws_route_table.a5_route_table.id
}

resource "aws_security_group" "allow_ssh_http" {
  name        = "allow_ssh_http"
  description = "Allow SSH and HTTP inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.a5_vpc.id
  tags = {
    Name = "allow-ssh-http"
  }
}
resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.allow_ssh_http.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # all ports
}
resource "aws_vpc_security_group_ingress_rule" "allow_http" {
  security_group_id = aws_security_group.allow_ssh_http.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
}
resource "aws_vpc_security_group_ingress_rule" "allow_https" {
  security_group_id = aws_security_group.allow_ssh_http.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}
resource "aws_vpc_security_group_ingress_rule" "allow_ssh" {
  security_group_id = aws_security_group.allow_ssh_http.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
}

##### COGNITO CONFIGURATION

resource "aws_cognito_user_pool_client" "client" {
  name                                 = "tic-tac-toe-terra-client"
  user_pool_id                         = aws_cognito_user_pool.pool.id
  callback_urls                        = ["https://user3148951frontend.us-east-1.elasticbeanstalk.com/login/"]
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code", "implicit"]
  allowed_oauth_scopes                 = ["email", "openid"]
  explicit_auth_flows                  = ["ALLOW_USER_PASSWORD_AUTH", "ALLOW_USER_SRP_AUTH", "ALLOW_REFRESH_TOKEN_AUTH"]
  supported_identity_providers         = ["COGNITO"]
  depends_on = [
    aws_cognito_user_pool.pool
  ]
}

resource "aws_cognito_user_pool" "pool" {
  name = "tic-tac-toe-terra"

  email_configuration {
    email_sending_account = "COGNITO_DEFAULT"
  }
  auto_verified_attributes = ["email"]

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }
  schema {
    name = "email"
    developer_only_attribute = false
    mutable                  = true
    attribute_data_type = "String"
    required = true
    string_attribute_constraints {
      max_length = 50
      min_length = 1
    }
  }
}

resource "aws_cognito_user_pool_domain" "main" {
  domain          = "user3148951tictactoe-terra"
  user_pool_id    = aws_cognito_user_pool.pool.id
}
resource "aws_cognito_resource_server" "resource" {
  user_pool_id = aws_cognito_user_pool.pool.id
  identifier = "user3148951tictactoe-terra-rs"
  name       = "user3148951tictactoe-terra-rs"
}

##### APPLICATION CONFIGURATION

resource "aws_s3_bucket" "default" {
  bucket = "tic-tac-toe.v1.bucket"
}

resource "aws_s3_object" "backend" {
  bucket = aws_s3_bucket.default.id
  key    = "backend-v1.zip"
  source = "backend-v1.zip"
  etag    = filemd5("backend-v1.zip")
}
resource "aws_s3_object" "frontend" {
  bucket = aws_s3_bucket.default.id
  key    = "frontend-v1.zip"
  source = "frontend-v1.zip"
  etag    = filemd5("frontend-v1.zip")
}

resource "aws_elastic_beanstalk_application" "tic-tac-toe-back" {
  name        = "tic-tac-toe-back"
  description = "tic-tac-toe backend"
}

resource "aws_elastic_beanstalk_application_version" "tic-tac-toe-back" {
  name        = "tic-tac-toe-back-v1"
  application = "tic-tac-toe-back"
  description = "tic-tac-toe backend v1"
  bucket      = aws_s3_bucket.default.id
  key         = aws_s3_object.backend.id
  depends_on = [
    aws_elastic_beanstalk_application.tic-tac-toe-back
  ]
}

resource "aws_elastic_beanstalk_environment" "backend-env-v1" {
  name        = "backend-env-v1"
  application = aws_elastic_beanstalk_application.tic-tac-toe-back.name
  version_label = "tic-tac-toe-back-v1"
  cname_prefix = "user3148951backend"
  solution_stack_name = "64bit Amazon Linux 2023 v4.3.1 running Docker"
   setting {
     namespace = "aws:elasticbeanstalk:application:environment"
     name = "DOMAIN"
     value = "https://${aws_cognito_user_pool_domain.main.domain}.auth.us-east-1.amazoncognito.com"
   }
   setting {
     namespace = "aws:ec2:vpc"
     name = "VPCId"
     value = aws_vpc.a5_vpc.id
   }
   setting {
     namespace = "aws:ec2:vpc"
     name = "Subnets"
     value = aws_subnet.a5_subnet.id
   }
  setting {
    namespace = "aws:ec2:vpc"
    name = "AssociatePublicIpAddress"
    value = "true"
  }
  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name = "EnvironmentType"
    value = "SingleInstance"
  }
  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name = "ServiceRole"
    value = "arn:aws:iam::851725491071:role/LabRole"
  }
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name = "IamInstanceProfile"
    value = "arn:aws:iam::851725491071:instance-profile/LabInstanceProfile"
  }
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name = "EC2KeyName"
    value = "vockey"
  }
  setting {
    namespace = "aws:ec2:instances"
    name = "InstanceTypes"
    value = "t2.micro"
  }
  depends_on = [
   aws_elastic_beanstalk_application.tic-tac-toe-back,
   aws_elastic_beanstalk_application_version.tic-tac-toe-back,
   aws_cognito_user_pool_client.client
  ]
}

resource "aws_elastic_beanstalk_application" "tic-tac-toe-front" {
  name        = "tic-tac-toe-front"
  description = "tic-tac-toe frontend"
}

resource "aws_elastic_beanstalk_application_version" "tic-tac-toe-front" {
  name        = "tic-tac-toe-front-v1"
  application = "tic-tac-toe-front"
  description = "tic-tac-toe frontend v1"
  bucket      = aws_s3_bucket.default.id
  key         = aws_s3_object.frontend.id
  depends_on = [
    aws_elastic_beanstalk_application.tic-tac-toe-front
  ]
}
resource "aws_elastic_beanstalk_environment" "frontend-env-v1" {
  name        = "frontend-env-v1"
  application = aws_elastic_beanstalk_application.tic-tac-toe-front.name
  version_label = "tic-tac-toe-front-v1"
  cname_prefix = "user3148951frontend"
  solution_stack_name = "64bit Amazon Linux 2023 v4.3.1 running Docker"
  setting {
     namespace = "aws:elasticbeanstalk:application:environment"
     name = "DOMAIN"
     value = "https://${aws_cognito_user_pool_domain.main.domain}.auth.us-east-1.amazoncognito.com"
   }
   setting {
     namespace = "aws:elasticbeanstalk:application:environment"
     name = "CLIENTID"
     value = aws_cognito_user_pool_client.client.id
   }
   setting {
     namespace = "aws:ec2:vpc"
     name = "VPCId"
     value = aws_vpc.a5_vpc.id
   }
   setting {
     namespace = "aws:ec2:vpc"
     name = "Subnets"
     value = aws_subnet.a5_subnet.id
   }
  setting {
    namespace = "aws:ec2:vpc"
    name = "AssociatePublicIpAddress"
    value = "true"
  }
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name = "SecurityGroups"
    value = aws_security_group.allow_ssh_http.id
  }
  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name = "EnvironmentType"
    value = "SingleInstance"
  }
  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name = "ServiceRole"
    value = "arn:aws:iam::851725491071:role/LabRole"
  }
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name = "IamInstanceProfile"
    value = "arn:aws:iam::851725491071:instance-profile/LabInstanceProfile"
  }
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name = "EC2KeyName"
    value = "vockey"
  }
  setting {
    namespace = "aws:ec2:instances"
    name = "InstanceTypes"
    value = "t2.micro"
  }
  depends_on = [
   aws_elastic_beanstalk_application.tic-tac-toe-front,
   aws_elastic_beanstalk_application_version.tic-tac-toe-front,
   aws_security_group.allow_ssh_http,
   aws_cognito_user_pool_client.client
  ]
}
