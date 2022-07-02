# Setting up CloudWatch to monitor Molecule JMX

AWS Cloudwatch can be used to monitor logs and metrics. To use AWS Cloudwatch with the Boomi runtimes there needs to be two agents involved. First, the amazon-cloudwatch-agent will be used to send data to Cloudwatch and the second agent will be collectd, which will be used to retrieve JMX properties from the Boomi runtime.

## Before getting started add IAM Role to EC2 instance

The CloudWatch Agent uses a policy that is attached to a role, and then attached to the EC2 instance. CloudWatchAgentAdminPolicy is the AWS managed policy that will be used. A copy of the policy is enclosed within the repo, [amazon-cloudwatch-agent.json](https://github.com/adambedenbaugh/aws-cloudwatch-boomi-monitor/blob/a4bc59e0f596a0eaca3af298c4e07ec4c54bb696/aws-cloudwatch-policy.json).

## Installing collectd

[collectd](https://collectd.org/) is a powerful and robust service that is used to collect metrics. It’s built on C and uses plug-ins for it’s functionality. We’ll be covering the plug-ins for [logging](https://collectd.org/wiki/index.php/Plugin:LogFile) of collectd, [java](https://collectd.org/wiki/index.php/Plugin:Java), and [jmx](https://collectd.org/wiki/index.php/Plugin:GenericJMX). 

First we will want to install a few packages. I’ll be assuming RHEL as the linux distribution.

```
# Install the Amazon Linux Extras package
sudo yum install -y amazon-linux-extras

# Install a local version of java. 
# You can use the Boomi's runtime version of Java as an additional option.
amazon-linux-extras install -y java-openjdk11 

# Install collectd and additional packages
amazon-linux-extras install -y collectd
sudo yum install -y collectd-java 
sudo yum install -y collectd-generic-jmx
```


Once, that is installed, next create a symlink for libjvm.so. There will likely be two or more libjvm.so files on the server. To find all locations execute locate libjvm.so. collectd is assuming that it is located within /usr/lib64/ and will fail to load it is not found. There are [other ways](https://github.com/collectd/collectd/blob/main/docs/BUILD.java.md) to achieve this same configuration but I found this to be the easiest to implement. 

```
# Look for the libjvm.so that's within the java-11-openjdk directory.
# The directory is from the java-openjdk11 that was installed earlier.
libjvm_location=$(locate libjvm.so | grep -m 1 'java-11-openjdk')
ln -s $libjvm_location /usr/lib64/libjvm.so
```

Next, modify the collectd.conf file and overwrite what is currently within /etc/collectd.conf.

Within collectd.conf there are 4 plugins being used. logfile will write the collectd logs to /var/log/collectd.log. This file can be helpful to troubleshoot issues. The LogLevel can be changed to info, which will populate the log file with metrics. The conf file below has it set to warning to limit the amount of data within the file. The write_log plugin defines the format that data is written to in the collectd.log file. 

The java plugin has a java and a GenericJMX plugin within. They are used to monitor the JMX properties. The connection section defines how to connect to the Boomi runtime.

Finally, the network plugin acts as a server for the Amazon CloudWatch Agent to listen to for metrics.

collectd has now been setup.


## Installing Amazon CloudWatch Agent

```
# Install Amazon CloudWatch Agent
sudo yum install -y amazon-cloudwatch-agent
```

`amazon-cloudwatch-agent` will get installed to `/opt/aws/amazon-cloudwatch-agent/bin`. There are a few ways to start amazon-cloudwatch-agent. `bin/amazon-cloudwatch-agent-config-wizard` will start the auto config. This is helpful if you do not know what you want. 

For us, we are going to use the config file that is below and implement it by running the following command. The user that the server is being run as is defined. Additional, under the collectd metrics, the connection that was referenced earlier under network is defined. 

```
# Set the CloudWatch Agent's directory
AWS_CLOUDWATCH_AGENT_HOME="/opt/aws/amazon-cloudwatch-agent/bin"

# Create or overwrite what is in the amazon-cloudwatch-agent.json
# with what is below
sudo vi $AWS_CLOUDWATCH_AGENT_HOME/amazon-cloudwatch-agent.json

$AWS_CLOUDWATCH_AGENT_HOME/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c file:$AWS_CLOUDWATCH_AGENT_HOME/amazon-cloudwatch-agent.json
```

Used the `amazon-cloudwatch-agent.json`.


## Bash Script for Automation

The previous sections outline the manual steps. The aws-cloudwatch-boomi-monitor.sh script can automate those steps. Place the bash script, collectd.conf, and amazon-cloudwatch-agent.json files into the same directory by cloning the repo. Then execute the aws-cloudwatch-boomi-monitor.sh bash script.


## Setting Up Cloudwatch

Go to Cloudwatch and use the following path to start monitoring the JMX metrics.
Metrics -> All Metrics -> Browse -> CWAgent -> ImageId, InstanceId, InstanceType, instance, type, type_instance (there are multiple that look similar)


## Troubleshooting

There are two log files that can be useful for determining errors.

```
# Amazon CloudWatch Logs
vi /opt/aws/amazon-cloudwatch-agent/logs/amazon-cloudwatch-agent.log

# collectd log file. 
# Update LogLevel within collectd.conf to info to see more detail
vi /var/log/collectd.log
```

## Additional Links

[Installing CloudWatch Agent on EC2](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/install-CloudWatch-Agent-on-EC2-Instance.html)
[How to Better Monitor Your Custom Application Metrics Using Amazon CloudWatch Agent](https://aws.amazon.com/blogs/devops/new-how-to-better-monitor-your-custom-application-metrics-using-amazon-cloudwatch-agent/)
[Start the CloudWatch Agent](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/install-CloudWatch-Agent-on-EC2-Instance-fleet.html#start-CloudWatch-Agent-EC2-fleet)
[Quick Start: Install and configure the CloudWatch Logs agent on a running EC2 Linux instance - Includes Required Policy](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/QuickStartEC2Instance.html)

