# IAM role for executing ECS Task
resource "aws_iam_role" "this" {
  name = "ecs-execution-role-for-${var.name}"
  assume_role_policy = jsonencode({                         # Define the trust relationship policy for the IAM role using JSON encoding
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"           # ECS tasks are the trusted entity allowed to assume this role
        }
      },
    ]
  })

  tags = {
    Name = "${var.name}"
  }
}

# This managed role has permissions to pull images from ECR and to push logs to CloudWatch logs
resource "aws_iam_role_policy_attachment" "this" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# The name of the CloudWatch log group, passed in as a variable
resource "aws_cloudwatch_log_group" "this" {
  name = var.name
  retention_in_days = 7
}

resource "aws_ecs_task_definition" "this" {
  family = "${var.name}"                            # Name of the task definition family
  container_definitions = jsonencode([           # Definition of the container(s) used in the task
    {                                                      
      name      = "${var.name}-container"
      image     = "${var.image_repository}:${var.image_tag}"      # Docker image to use
      cpu       = 256
      memory    = 512          # Memory in MiB allocated to the container
      essential = true                            # Marks this container as essential (if it crashes, the task stops)
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
        }
      ]
      logConfiguration = {                                    
        logDriver = "awslogs"
        options = {
          awslogs-group = var.name
          awslogs-region = "us-east-1"
          awslogs-stream-prefix = "app-logs"
        }
      }
    }
  ])
  cpu = 256                     # CPU and memory settings for the entire task
  memory = 512
  network_mode = "awsvpc"
  requires_compatibilities = ["FARGATE"]                              # Specifies Fargate as the launch type
  execution_role_arn = aws_iam_role.this.arn                      # IAM role that ECS uses to pull images and write logs
}



# ALB Setup
resource "aws_lb_target_group" "this" {
  name        = "${var.name}"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"           # Target type is 'ip' since ECS Fargate uses IP addresses, not EC2 instance IDs
  vpc_id      = var.vpc_id
}

resource "aws_security_group" "alb_sg" {
  name        = "${var.name}-alb-sg"
  description = "ALB security group for ${var.name}"
  vpc_id      = var.vpc_id            # The VPC where the security group will be applied

  tags = {                                  # Tags to help identify and organize the security group in AWS
    Name = "${var.name} ALB SG"
  }
}

resource "aws_vpc_security_group_ingress_rule" "alb_sg_http_in" {
  security_group_id = aws_security_group.alb_sg.id
  cidr_ipv4         = "0.0.0.0/0"                  # Allow inbound traffic from all IP addresses
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_egress_rule" "alb_sg_http_out_to_tasks" {
  security_group_id = aws_security_group.alb_sg.id
  referenced_security_group_id         = aws_security_group.service_sg.id        # Specifies the security group that traffic will be sent to (tasks' security group)
  ip_protocol       = "tcp"
  from_port = 80
  to_port = 80
}

resource "aws_lb" "this" {
  name               = "${var.name}-alb"
  internal           = false        # Set to 'false' to make the ALB publicly accessible (for external traffic)
  load_balancer_type = "application"          # Specifies the type of load balancer (Application Load Balancer for HTTP/HTTPS traffic)
  security_groups    = [aws_security_group.alb_sg.id]                          # Security groups attached to the load balancer, using the previously defined ALB SG
  subnets            = var.alb_subnets                # Subnets where the ALB will be placed

  tags = {
    Name = "${var.name}-alb"
  }
}

resource "aws_lb_listener" "this" {
  load_balancer_arn = aws_lb.this.arn         # ARN of the load balancer where this listener will be attached
  port              = "80"              # Port on which the listener will listen 
  protocol          = "HTTP"

  default_action {
    type             = "forward"                  # Action type (forward traffic to a target group)
    target_group_arn = aws_lb_target_group.this.arn
  }
}




# ECS Service
resource "aws_security_group" "service_sg" {
  name = "${var.name}-service-sg"               # Name of the security group for the service
  description = "${var.name} Service SG"
  vpc_id      = var.vpc_id                      # The VPC where this security group will be created
  
  tags = {
    Name = "${var.name} Service SG"
  }
}

resource "aws_vpc_security_group_ingress_rule" "service_sg_http_in_from_alb" {
  security_group_id = aws_security_group.service_sg.id
  referenced_security_group_id = aws_security_group.alb_sg.id       # Specifies the security group that is allowed to send traffic to this security group (ALB's security group)
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_egress_rule" "service_sg_https_egress" {
  security_group_id = aws_security_group.service_sg.id
  cidr_ipv4         = "0.0.0.0/0"            # Specifies that outbound traffic is allowed to any IP address                                               
  from_port = 443
  to_port = 443
  ip_protocol       = "tcp"
}

resource "aws_ecs_service" "this" {
  name            = "${var.name}"
  cluster         = var.cluster_id
  task_definition = aws_ecs_task_definition.this.arn             # The task definition ARN to run as the service, referencing the ECS task definition resource
  desired_count   = 2                   # The number of tasks (containers) to run in the ECS service
  launch_type = "FARGATE"      # Launch type defines where the service will run; "FARGATE" means the service will run on AWS Fargate (serverless container platform)

  network_configuration {
    subnets = var.task_subnets
    security_groups = [aws_security_group.service_sg.id]                  # The security groups that will be assigned to the ECS tasks;
    assign_public_ip = true          # Whether to assign a public IP to the ECS tasks (set to true for internet-facing tasks)                                   
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.this.arn     # ARN of the target group where the load balancer will send traffic
    container_name   = "${var.name}-container"
    container_port   = 80     # The port on the container that will receive the traffic 
  }
}
