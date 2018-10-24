#!/bin/sh

host_ip=$1

# install nginx
ssh -oStrictHostKeyChecking=no centos@$host_ip "sudo yum install -y httpd; sudo systemctl start httpd; sudo systemctl enable httpd"

# copy data
rsync --delete --rsync-path="sudo rsync" -avz -e "ssh -oStrictHostKeyChecking=no" opendata-jkan/_site/ centos@$host_ip:/var/www/html/
