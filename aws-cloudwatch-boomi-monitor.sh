#!/bin/sh
# Script must be ran as root

# Install collectd
echo "Installing collectd ..."
yum install -y amazon-linux-extras
amazon-linux-extras install -y java-openjdk11
amazon-linux-extras install -y collectd
yum install -y collectd-java
yum install -y collectd-generic-jmx


# Looking for libjvm.so from the java-openjdk11 package that was installed
LIBJVM_SYMLINK=/usr/lib64/libjvm.so
if [ -L ${LIBJVM_SYMLINK} ] && [ -e ${LIBJVM_SYMLINK} ]; then
    echo "Synlink to libjvm.so already exists. Skipping..."
else
    libjvm_location=$(locate libjvm.so | grep -m 1 'java-11-openjdk')
    echo "libjvm_location: $libjvm_location"
    ln -s $libjvm_location /usr/lib64/libjvm.so
fi


cat collectd.conf >| /etc/collectd.conf
HOST_NAME=$(hostname | xargs)
sed -i "s/HOST_NAME/${HOST_NAME}/" /etc/collectd.conf

# Install Amazon Cloudwatch Agent
echo "Installing Amaon Cloudwatch Agent ..."
yum install -y amazon-cloudwatch-agent     > /dev/null
AWS_CLOUDWATCH_AGENT_HOME="/opt/aws/amazon-cloudwatch-agent/bin"
cat amazon-cloudwatch-agent.json >| $AWS_CLOUDWATCH_AGENT_HOME/amazon-cloudwatch-agent.json
$AWS_CLOUDWATCH_AGENT_HOME/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c file:$AWS_CLOUDWATCH_AGENT_HOME/amazon-cloudwatch-agent.json  > /dev/null
INTERNAL_IP_ADDRESS=$(hostname -I | sed 's/\./_/g' | xargs)
sed -i "s/INTERNAL_IP_ADDRESS/${INTERNAL_IP_ADDRESS}/" $AWS_CLOUDWATCH_AGENT_HOME/amazon-cloudwatch-agent.json

echo "Setting up systemd for collectd and amazon-cloudwatch-agent"
systemctl enable collectd
systemctl stop collectd
systemctl start collectd
systemctl enable amazon-cloudwatch-agent
systemctl stop amazon-cloudwatch-agent
systemctl start amazon-cloudwatch-agent


echo "Installation successful!"