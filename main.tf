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
              sudo apt-get update
              sudo apt-get install -y wget
              wget https://github.com/prometheus/prometheus/releases/download/v2.37.0/prometheus-2.37.0.linux-amd64.tar.gz
              tar xvfz prometheus-*.tar.gz
              cd prometheus-2.37.0.linux-amd64
              sudo cp prometheus /usr/local/bin/
              sudo cp promtool /usr/local/bin/
              sudo mkdir /etc/prometheus
              sudo cp -r consoles/ console_libraries/ /etc/prometheus/
              sudo cp prometheus.yml /etc/prometheus/prometheus.yml
              sudo useradd --no-create-home --shell /bin/false prometheus
              sudo chown -R prometheus:prometheus /etc/prometheus /usr/local/bin/prometheus /usr/local/bin/promtool
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
              sudo systemctl daemon-reload
              sudo systemctl enable prometheus
              sudo systemctl start prometheus
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


