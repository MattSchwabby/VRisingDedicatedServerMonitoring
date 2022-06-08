# V Rising Dedicated Server Monitoring

This package contains three PowerShell scripts that will create two Lambdas in AWS that emit basic metrics for a V Rising dedicated server.

## Prerequisites

[PowerShell (at least version 6)](https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows?view=powershell-7.2)
[The AWSPowershell module](https://www.google.com/url?sa=t&rct=j&q=&esrc=s&source=web&cd=&cad=rja&uact=8&ved=2ahUKEwjDie-V4Z74AhU1IX0KHe9jAskQFnoECB8QAQ&url=https%3A%2F%2Faws.amazon.com%2Fpowershell%2F&usg=AOvVaw2NGzyAPleVfgzaGNesFfQb)
[AWS Lambda Tools for PowerShell](https://github.com/aws/aws-lambda-dotnet/tree/master/PowerShell)
A [V Rising Dedicated Server](https://www.google.com/url?sa=t&rct=j&q=&esrc=s&source=web&cd=&cad=rja&uact=8&ved=2ahUKEwjNq82x4Z74AhXAIzQIHXE2DG4QFnoECAYQAQ&url=https%3A%2F%2Fgithub.com%2FStunlockStudios%2Fvrising-dedicated-server-instructions&usg=AOvVaw1Bjr4s8fYYTOxjyTDh8suY) running the [CloudWatch Agent](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/install-CloudWatch-Agent-on-EC2-Instance.html) configured to [export the server's log file to CloudWatch logs](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/create-cloudwatch-agent-configuration-file.html).

## Metrics

The Lambdas will monitor two metrics:
- Server Health: Assessed by calling the Steamworks health check API for a target IP address.
- Active Players: Calculated by parsing the V Rising Dedicated Server's log file.

These metrics will be emitted as CloudWatch metrics in the "V Rising Dedicated Server" Namespace. Both metrics will be aggregated under a shared dimension of the server's name.

## Set up

Before running the script, you must install and configure the [CloudWatch agent](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Install-CloudWatch-Agent.html) on your dedicated server. This is very simple to do, and can be conducted via [Systems Manager run commands](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/installing-cloudwatch-agent-ssm.html) if your server is a managed EC2 instance, or has been [activated by a Systems Manager activation](https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-managedinstances.html). In order for the Active Players lambda to successfully emit its metric, the agent must be configured to export the V Rising Dedicated Server's log file to a CloudWatch log stream. This requires one line to be added to the CloudWatch configuration file's "logs" configuration section [an example configuration file can be seen here](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch-Agent-Configuration-File-Details.html). Alternatively, you can run the [CloudWatch Agent configuration Wizard](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/create-cloudwatch-agent-configuration-file-wizard.html) which comes bundled with a CloudWatch agent installation, and specify the log file's path when running the wizard.

## IAM Permissions

The script will create an execution role for the Lambdas execution with the following permissions policies:
- CloudWatchFullAccess
- CloudWatchLogsFullAccess

## Preparing the script

There are a number of variables you'll need to set in the three script files:
From `Publish-MonitoringLambdas.ps1`:
`$Region` - The region the Lambdas will be created in (defaults to `us-west-2`),
`$IAMRoleName` - The name of the IAM role that will be created at deployment (defaults to `VRisingDedicatedServerMonitoringRole`).
`$ScheduleExpression` - The frequency of the Event Bridge rules that will trigger the Lambdas (defaults to `rate(minutes 5)`),

From `Get-ConnectedVRisingPlayers.ps1`:
`$ServerName` - The name of the V Rising Dedicated server you're running. This is purely cosmetic and doesn't actually need to math the server's published name.
`$LogStreamName ` - The name of the Log Stream that your CloudWatch agent exports the dedicated server's logs to (The CloudWatch agent configuration wizard defaults to the instance's name).
`$LogGroupName` - The name of the log group that your CloudWatch agent exports the dedicated server's logs to (The CloudWatch agent configuration wizard defualts to the name of the log file on the local machine).

Finally, from `Get-VRisingServerHealthCheck.ps1`:
`$ServerName` = The name of the V Rising Dedicated server you're running. This is purely cosmetic and doesn't actually need to math the server's published name.
`$URI` - The URI for the Steam health check. Must include the dedicated server's Public IPv4 address and the query port (defaults to 9877) that is configured in the server's `ServerHostSettings.json` file (example: `https://api.steampowered.com/ISteamApps/GetServersAtAddress/v0001?addr=192.168.0.1:9877`

## Running the script

Authenticate with admin credentials in the AWS account you want to deploy the Lambdas and other infrastructure in.

Pull down this repo

```sh
git clone https://github.com/MattSchwabby/VRisingDedicatedServerMonitoring.git
cd VRisingDedicatedServerMonitoring
./Publish-MonitoringLambdas.ps1.ps1
```

## What if I want to run the code from my server?

This package can easily be modified to run as scheduled tasks directly from the dedicated server, if desired. The main file you'll need to edit is `Get-ConnectedVRisingPlayers.ps1`'s invocation of the `Write-ConnectedVRisingPlayersCloudwatch` function. There is a parameter set with a `isLocalLogFile` switch that takes `logFilePath` as a parameter. Adding that switch and passing in the log file's local path will make the function impart and parse the local file instead of ingesting the CloudWatch log events.