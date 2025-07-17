#!/bin/bash
yum install -y httpd
systemctl start httpd
echo "<h1>TURN Server Setup Placeholder</h1>" > /var/www/html/index.html

