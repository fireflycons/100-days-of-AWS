terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

variable "prefix" {
  description = "Infrastructure prefix"
  type        = string
}

variable "lambda_role_name" {
  description = "Lambda execution role name"
  type        = string
  default     = "lambda_execution_role"
}

resource "local_file" "cloudformation" {
  filename = "${path.module}/cloudformation.yaml"

  content = <<YAML
AWSTemplateFormatVersion: '2010-09-09'
Description: SQS priority queues template

Resources:
  SQSHighPriorityQueue:
    Type: AWS::SQS::Queue
    Properties:
      VisibilityTimeout: 180
      QueueName: ${var.prefix}-High-Priority-Queue

  SQSLowPriorityQueue:
    Type: AWS::SQS::Queue
    Properties:
      VisibilityTimeout: 180
      QueueName: ${var.prefix}-Low-Priority-Queue

  PriorityQueuesTopic:
    Type: AWS::SNS::Topic
    Properties:
      TopicName: ${var.prefix}-Priority-Queues-Topic

  SQSHighQueuePolicy:
    Type: AWS::SQS::QueuePolicy
    Properties:
      Queues:
        - !Ref SQSHighPriorityQueue
      PolicyDocument:
        Id: AllowIncomingMessageFromSNS
        Statement:
          - Effect: Allow
            Principal: "*"
            Action:
              - sqs:SendMessage
            Resource:
              - !GetAtt SQSHighPriorityQueue.Arn
            Condition:
              ArnEquals:
                aws:SourceArn: !Ref PriorityQueuesTopic

  SQSLowQueuePolicy:
    Type: AWS::SQS::QueuePolicy
    Properties:
      Queues:
        - !Ref SQSLowPriorityQueue
      PolicyDocument:
        Id: AllowIncomingMessageFromSNS
        Statement:
          - Effect: Allow
            Principal: "*"
            Action:
              - sqs:SendMessage
            Resource:
              - !GetAtt SQSLowPriorityQueue.Arn
            Condition:
              ArnEquals:
                aws:SourceArn: !Ref PriorityQueuesTopic

  SNSHighSubscription:
    Type: AWS::SNS::Subscription
    Properties:
      TopicArn: !Ref PriorityQueuesTopic
      Endpoint: !GetAtt SQSHighPriorityQueue.Arn
      Protocol: sqs
      RawMessageDelivery: true
      FilterPolicy: {"priority": ["high"]}

  SNSLowSubscription:
    Type: AWS::SNS::Subscription
    Properties:
      TopicArn: !Ref PriorityQueuesTopic
      Endpoint: !GetAtt SQSLowPriorityQueue.Arn
      Protocol: sqs
      RawMessageDelivery: true
      FilterPolicy: {"priority": ["low"]}

  LambdaRole:
    Type: AWS::IAM::Role
    Properties:
      RoleName: ${var.lambda_role_name}
      AssumeRolePolicyDocument:
        Version: "2012-10-17"
        Statement:
          - Effect: Allow
            Action:
              - sts:AssumeRole
            Principal:
              Service:
                - lambda.amazonaws.com
      ManagedPolicyArns:
        - arn:aws:iam::aws:policy/AmazonSQSFullAccess
      Path: /

  LambdaFunction:
    Type: AWS::Lambda::Function
    Properties:
      FunctionName: ${var.prefix}-priorities-queue-function
      Description: Priority queue function
      Runtime: python3.9
      Handler: index.lambda_handler
      MemorySize: 128
      Timeout: 10
      Role:
        Fn::GetAtt:
          - LambdaRole
          - Arn
      Code:
        ZipFile: ${jsonencode(file("/root/index.py"))}

      Environment:
        Variables:
          high_priority_queue: !Ref SQSHighPriorityQueue
          low_priority_queue: !Ref SQSLowPriorityQueue

  HighPriorityEventSource:
    Type: AWS::Lambda::EventSourceMapping
    Properties:
      EventSourceArn: !GetAtt SQSHighPriorityQueue.Arn
      FunctionName: !Ref LambdaFunction
      BatchSize: 1
      Enabled: true

Outputs:
  SNSTopicARN:
    Value: !Ref PriorityQueuesTopic
YAML
}

resource "aws_cloudformation_stack" "priority_queues" {
  name          = "${var.prefix}-priority-queues-stack"
  template_body = local_file.cloudformation.content

  capabilities = [
    "CAPABILITY_NAMED_IAM",
    "CAPABILITY_IAM"
  ]
}