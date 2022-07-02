#!/bin/sh
# Script must be ran as root

if [ -x "$(command -v apk)" ];       then PACKAGE_MANAGER='apk'
elif [ -x "$(command -v apt-get)" ]; then PACKAGE_MANAGER='apt-get'
elif [ -x "$(command -v dnf)" ];     then PACKAGE_MANAGER='dnf'
elif [ -x "$(command -v yum)" ];     then PACKAGE_MANAGER='yum'
elif [ -x "$(command -v zypper)" ];  then PACKAGE_MANAGER='zypper'
else echo "FAILED TO INSTALL: Package manager not found.">&2; fi

echo "Installing collectd ..."
# Install collectd
$PACKAGE_MANAGER install -y amazon-linux-extras         > /dev/null
amazon-linux-extras install -y java-openjdk11           > /dev/null
amazon-linux-extras install -y collectd                 > /dev/null
$PACKAGE_MANAGER install -y collectd-java               > /dev/null
$PACKAGE_MANAGER install -y collectd-generic-jmx        > /dev/null

# Looking for libjvm.so from the java-openjdk11 package that was installed
LIBJVM_SYMLINK=/usr/lib64/libjvm.so
if [ -L ${LIBJVM_SYMLINK} ] && [ -e ${LIBJVM_SYMLINK} ]; then
    echo "Synlink to libjvm.so already exists. Skipping..."
else
    libjvm_location=$(locate libjvm.so | grep -m 1 'java-11-openjdk')   > /dev/null
    echo "libjvm_location: $libjvm_location"
    ln -s $libjvm_location /usr/lib64/libjvm.so         > /dev/null
fi

cat collectd.conf >| /etc/collectd.conf

echo "Installing Amaon Cloudwatch Agent ..."
# Install Amazon Cloudwatch Agent
$PACKAGE_MANAGER install -y amazon-cloudwatch-agent     > /dev/null

AWS_CLOUDWATCH_AGENT_HOME="/opt/aws/amazon-cloudwatch-agent/bin"

cat amazon-cloudwatch-agent.json >| $AWS_CLOUDWATCH_AGENT_HOME/amazon-cloudwatch-agent.json

$AWS_CLOUDWATCH_AGENT_HOME/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c file:$AWS_CLOUDWATCH_AGENT_HOME/amazon-cloudwatch-agent.json  > /dev/null

systemctl enable collectd                               > /dev/null
systemctl stop collectd                                 > /dev/null
systemctl start collectd                                > /dev/null
systemctl enable amazon-cloudwatch-agent                > /dev/null
systemctl stop amazon-cloudwatch-agent                  > /dev/null
systemctl start amazon-cloudwatch-agent                 > /dev/null