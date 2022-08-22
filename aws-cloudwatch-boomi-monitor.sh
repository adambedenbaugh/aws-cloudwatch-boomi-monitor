#!/bin/sh
# Script must be ran as root

if [ -x "$(command -v apk)" ];       then PACKAGE_MANAGER='apk'
elif [ -x "$(command -v apt-get)" ]; then PACKAGE_MANAGER='apt-get'
elif [ -x "$(command -v dnf)" ];     then PACKAGE_MANAGER='dnf'
elif [ -x "$(command -v yum)" ];     then PACKAGE_MANAGER='yum'
elif [ -x "$(command -v zypper)" ];  then PACKAGE_MANAGER='zypper'
else echo "FAILED TO INSTALL: Package manager not found.">&2; fi

# Install collectd
echo "Installing collectd ..."
{
    $PACKAGE_MANAGER install -y amazon-linux-extras
    amazon-linux-extras install -y java-openjdk11
    amazon-linux-extras install -y collectd
    $PACKAGE_MANAGER install -y collectd-java
    $PACKAGE_MANAGER install -y collectd-generic-jmx
} > /dev/null

# Looking for libjvm.so from the java-openjdk11 package that was installed
{
    LIBJVM_SYMLINK=/usr/lib64/libjvm.so
    if [ -L ${LIBJVM_SYMLINK} ] && [ -e ${LIBJVM_SYMLINK} ]; then
        echo "Synlink to libjvm.so already exists. Skipping..."
    else
        libjvm_location=$(locate libjvm.so | grep -m 1 'java-11-openjdk')
        echo "libjvm_location: $libjvm_location"
        ln -s $libjvm_location /usr/lib64/libjvm.so
    fi
} > /dev/null

cat collectd.conf >| /etc/collectd.conf

# Install Amazon Cloudwatch Agent
echo "Installing Amaon Cloudwatch Agent ..."
{
    $PACKAGE_MANAGER install -y amazon-cloudwatch-agent     > /dev/null
    AWS_CLOUDWATCH_AGENT_HOME="/opt/aws/amazon-cloudwatch-agent/bin"
    cat amazon-cloudwatch-agent.json >| $AWS_CLOUDWATCH_AGENT_HOME/amazon-cloudwatch-agent.json
    $AWS_CLOUDWATCH_AGENT_HOME/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c file:$AWS_CLOUDWATCH_AGENT_HOME/amazon-cloudwatch-agent.json  > /dev/null
} > /dev/null

echo "Setting up systemd for collectd and amazon-cloudwatch-agent"
{
    systemctl enable collectd
    systemctl stop collectd
    systemctl start collectd
    systemctl enable amazon-cloudwatch-agent
    systemctl stop amazon-cloudwatch-agent
    systemctl start amazon-cloudwatch-agent
} > /dev/null

echo "Installation successful!"