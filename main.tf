# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#                             AWS PROVIDER CONFIGURATION
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

provider "aws" {
  region = "us-east-1"  # Specify the AWS region for resource deployment
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#                             KEYPARS CONFIGURATION
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

resource "aws_key_pair" "deployer_key" {
  key_name   = "deployer-key"
  public_key = file("./fran.pub")
}



# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#                             SUBNET CONFIGURATION
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

resource "aws_subnet" "default" {
  vpc_id            = "vpc-0c19323b134a07b96"
  cidr_block        = "10.0.0.0/24"
  map_public_ip_on_launch = true
  availability_zone = "us-east-1a"

  tags = {
    Name = "my_subnet"
  }
}



# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#                             INSTANCES CONFIGURATION
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

resource "aws_instance" "prometheus" {
  ami           = "ami-07caf09b362be10b8"  
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.default.id
  vpc_security_group_ids = [aws_security_group.default.id]
  key_name      = aws_key_pair.deployer_key.key_name

  user_data = <<-EOF
  #!/bin/bash

  # Setup logging for the user data execution
  exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

  # Update system and install necessary packages
  sudo apt-get update
  sudo apt-get install -y wget

  # Download and extract Prometheus
  wget -qO- https://github.com/prometheus/prometheus/releases/download/v2.37.0/prometheus-2.37.0.linux-amd64.tar.gz | tar xvz -C /usr/local/bin --strip-components=1

  # Create necessary directories
  sudo mkdir -p /etc/prometheus
  sudo mkdir -p /var/lib/prometheus
  sudo mkdir -p /etc/prometheus/consoles
  sudo mkdir -p /etc/prometheus/console_libraries

  # Copy configuration and web assets
  sudo cp /usr/local/bin/consoles/*.html /etc/prometheus/consoles/
  sudo cp /usr/local/bin/console_libraries/*.js /etc/prometheus/console_libraries/
  sudo cp /usr/local/bin/prometheus.yml /etc/prometheus/

  # Create Prometheus user
  sudo useradd --no-create-home --shell /bin/false prometheus

  # Set permissions
  sudo chown -R prometheus:prometheus /etc/prometheus /var/lib/prometheus /usr/local/bin/prometheus /usr/local/bin/promtool

  # Create systemd service
  echo '[Unit]
  Description=Prometheus
  Wants=network-online.target
  After=network-online.target

  [Service]
  User=prometheus
  Group=prometheus
  Type=simple
  ExecStart=/usr/local/bin/prometheus \
    --config.file /etc/prometheus/prometheus.yml \
    --storage.tsdb.path /var/lib/prometheus/ \
    --web.console.templates=/etc/prometheus/consoles \
    --web.console.libraries=/etc/prometheus/console_libraries
  Restart=always

  [Install]
  WantedBy=multi-user.target' | sudo tee /etc/systemd/system/prometheus.service

  # Reload systemd to recognize the new service, enable and start Prometheus
  sudo systemctl daemon-reload
  sudo systemctl enable prometheus
  sudo systemctl start prometheus

  # Clean up apt cache to free up space
  sudo apt-get clean
  EOF


  tags = {
    Name = "Prometheus"
  }
}



resource "aws_instance" "grafana" {
  ami           = "ami-07caf09b362be10b8"  
  instance_type = "t2.micro"
  subnet_id = aws_subnet.default.id
  vpc_security_group_ids = [aws_security_group.default.id]
  key_name               = aws_key_pair.deployer_key.key_name



  user_data = <<-EOF
              #!/bin/bash
              sudo apt-get update
              sudo apt-get install -y apt-transport-https
              sudo add-apt-repository "deb https://packages.grafana.com/oss/deb stable main"
              sudo apt-get update
              sudo apt-get install grafana
              sudo systemctl start grafana-server
              EOF

  tags = {
    Name = "Grafana"
  }
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#                                SECURITY GROUPS
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

resource "aws_security_group" "default" {
  name        = "allow_web_ssh"
  description = "Allow web and SSH inbound traffic"
  vpc_id      = "vpc-0c19323b134a07b96"


  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

    ingress {
    description = "Prometheus"
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_web_ssh_sg"
  }
}


