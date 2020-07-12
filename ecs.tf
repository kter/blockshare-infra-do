resource "aws_ecs_cluster" "main" {
  name = "main"
}

data "template_file" "container_definition_json" {
  template = "${file("container_definitions.json")}"

  vars = {
    log_group = "${var.env}-${local.project_name}"
    log_prefix = "${local.project_name}-web"
    account_id = module.caller_identity.account_id
    project_name = local.project_name
  }
}

resource "aws_ecs_task_definition" "main" {
  family                   = "main"
  cpu                      = "256"
  memory                   = "512"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  container_definitions    = data.template_file.container_definition_json.rendered
  execution_role_arn = module.ecs_task_execution_role.iam_role_arn
}

resource "aws_ecs_service" "main" {
  name                              = "main"
  cluster                           = aws_ecs_cluster.main.arn
  task_definition                   = aws_ecs_task_definition.main.arn
  desired_count                     = 2
  launch_type                       = "FARGATE"
  platform_version                  = "1.3.0"
  health_check_grace_period_seconds = 60

  network_configuration {
    assign_public_ip = false
    security_groups  = [module.web_sg.security_group_id]

    subnets = [
      aws_subnet.private_0.id,
      aws_subnet.private_1.id,
    ]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.main.arn
    container_name   = "main"
    container_port   = 80
  }

  lifecycle {
    ignore_changes = [task_definition]
  }
}

module "web_sg" {
  source      = "./modules/security_group"
  name        = "web_sg"
  vpc_id      = aws_vpc.main.id
  port        = 80
  cidr_blocks = [aws_vpc.main.cidr_block]
}

resource "aws_cloudwatch_log_group" "for_ecs" {
  name              = "/ecs/${var.env}/${local.project_name}"
  retention_in_days = 180
}

data "aws_iam_policy" "ecs_task_execution_role_policy" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_iam_policy_document" "ecs_task_execution" {
  source_json = data.aws_iam_policy.ecs_task_execution_role_policy.policy

  statement {
    effect    = "Allow"
    actions   = ["ssm:GetParameters", "kms:Decrypt"]
    resources = ["*"]
  }
}

module "ecs_task_execution_role" {
  source     = "./modules/iam_role"
  name       = "ecs-task-execution"
  identifier = "ecs-tasks.amazonaws.com"
  policy     = data.aws_iam_policy_document.ecs_task_execution.json
}

resource "aws_ssm_parameter" "db_raw_password" {
  name = "/db/password"
  value = var.db_pass
  type = "SecureString"
}

resource "aws_s3_bucket" "cloudwatch_logs" {
  bucket = "${var.env}.app.logs.${local.project_name}"
  force_destroy = true

  lifecycle_rule {
    enabled = true

    expiration {
      days = "180"
    }
  }
}

data "aws_iam_policy_document" "kinesis_data_firehose" {
  statement {
    effect = "Allow"
    actions = [
      "s3:AbortMultipartUpload",
      "s3:GetBucketLocation",
      "s3:GetObject",
      "s3:ListBucket",
      "s3:ListBucketMultipartUploads",
      "s3:PutObject",
    ]
    resources = [
      "arn:aws:s3:::${aws_s3_bucket.cloudwatch_logs.id}",
      "arn:aws:s3:::${aws_s3_bucket.cloudwatch_logs.id}/*",
    ]
  }
}

module "kinesis_data_firehose_role" {
  source = "./modules/iam_role"
  name = "kinesis-data-firehose"
  identifier = "firehose.amazonaws.com"
  policy = data.aws_iam_policy_document.kinesis_data_firehose.json
}


resource "aws_kinesis_firehose_delivery_stream" "main" {
  destination = "s3"
  name = "main"

  s3_configuration {
    role_arn = module.kinesis_data_firehose_role.iam_role_arn
    bucket_arn = aws_s3_bucket.cloudwatch_logs.arn
    prefix = "ecs/main/"
  }
}

data "aws_iam_policy_document" "cloudwatch_logs" {
  statement {
    effect = "Allow"
    actions = ["firehose:*"]
    resources = ["arn:aws:firehose:us-east-1:*:*"]
  }
  statement {
    effect = "Allow"
    actions = ["iam:PassRole"]
    resources = ["arn:aws:iam::*:role/cloudwatch-logs"]
  }
}

module "cloudwatch_logs_role" {
  source = "./modules/iam_role"
  name = "cloudwatch-logs"
  identifier = "logs.us-east-1.amazonaws.com"
  policy = data.aws_iam_policy_document.cloudwatch_logs.json
}

resource "aws_cloudwatch_log_subscription_filter" "main" {
  name = "main"
  log_group_name = aws_cloudwatch_log_group.for_ecs.name
  destination_arn = aws_kinesis_firehose_delivery_stream.main.arn
  filter_pattern = "[]"
  role_arn = module.cloudwatch_logs_role.iam_role_arn
}