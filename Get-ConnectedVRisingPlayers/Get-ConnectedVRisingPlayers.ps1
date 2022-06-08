# PowerShell script file to be executed as a AWS Lambda function. 
# 
# When executing in Lambda the following variables will be predefined.
#   $LambdaInput - A PSObject that contains the Lambda function input data.
#   $LambdaContext - An Amazon.Lambda.Core.ILambdaContext object that contains information about the currently running Lambda environment.
#
# The last item in the PowerShell pipeline will be returned as the result of the Lambda function.
#
# To include PowerShell modules with your Lambda function, like the AWS.Tools.S3 module, add a "#Requires" statement
# indicating the module and version. If using an AWS.Tools.* module the AWS.Tools.Common module is also required.

#Requires -Modules @{ModuleName='AWS.Tools.Common';ModuleVersion='4.1.100'}
#Requires -Modules @{ModuleName='AWS.Tools.Cloudwatch';ModuleVersion='4.1.100'}
#Requires -Modules @{ModuleName='AWS.Tools.CloudWatchLogs';ModuleVersion='4.1.100'}

# Uncomment to send the input event to CloudWatch Logs
# Write-Host (ConvertTo-Json -InputObject $LambdaInput -Compress -Depth 5)

#region Variables
    $ServerName = "V Rising Dedicated Server"
    $LogStreamName = "V Rising Dedicated Server Log Stream"
    $LogGroupName = "V Rising Dedicated Server Log Group"
#endregion Variables

#region Import
    Import-Module AWS.Tools.Common
    Import-Module AWS.Tools.Cloudwatch
    Import-Module AWS.Tools.CloudWatchLogs
#endregion Import

#region Functions
    function Get-ConnectedVRisingPlayers{
        param(
            [Parameter(Mandatory=$false)]
            [Switch]$isLocalLogFile = $false,
            [String]$logFilePath,
            [Parameter(Mandatory=$false)]
            [Switch]$isCWLogFile = $True,
            [String]$LogStreamName,
            [String]$LogGroupName
        )
        if($isLocalLogFile){
            $logs = get-content $logFilePath
        }elseif($isCWLogFile){
            $logs = Get-CWLLogEvent -LogStreamName $LogStreamName -LogGroupName $LogGroupName -StartFromHead $false
            $logs = $logs.Events.Message
        }
        $connections = $logs | Where-Object {$_ -like "User '{Steam *"}

        $pattern = "User '{Steam (.*?)}' '"
        $matches = @()
        foreach($connection in $connections){
            $result = [regex]::match($connection, $pattern)
            $match = $result.Groups[1].Value
            $matches += $match
        }
        $UniqueConnections = $matches | Sort-Object | Get-Unique -AsString
        $matches = @()
        $pattern = "User '{Steam (.*?)}' disconnected"
        $matches = @()
        foreach($connection in $connections){
            $result = [regex]::match($connection, $pattern)
            $match = $result.Groups[1].Value
            $matches += $match
        }
        $UniqueDisconnections = $matches | Sort-Object | Get-Unique -AsString

        $ConnectedPlayers = Compare-Object -ReferenceObject $UniqueDisconnections -DifferenceObject $UniqueConnections
        $count = $ConnectedPlayers | measure-object
        Return $count.Count
    }

    Function Write-ConnectedVRisingPlayersCloudWatch
    {
        param(
            [Parameter(Mandatory=$false)]
            [Switch]$isLocalLogFile = $false,
            [String]$logFilePath,
            [Parameter(Mandatory=$false)]
            [Switch]$isCWLogFile = $True,
            [String]$LogStreamName,
            [String]$LogGroupName,
            [Parameter(Mandatory = $True)]
            [String]$ServerName
        )
        if($isLocalLogFile){
            $connectedPlayers = Get-ConnectedVRisingPlayers -isLocalLogFile -logFilePath $logFilePath
        }elseif($isCWLogFile){
            $connectedPlayers = Get-ConnectedVRisingPlayers -isCWLogFile -LogStreamName $LogStreamName -LogGroupName $logGroupName
        }
        $Metric = New-Object -TypeName Amazon.CloudWatch.Model.MetricDatum
        $dim=[Amazon.CloudWatch.Model.Dimension]::new()
        $dim.Name="ServerName"
        $dim.Value="$ServerName"
        $Metric.Timestamp = [DateTime]::UtcNow
        $Metric.MetricName = 'ConnectedPlayers'
        $metric.Dimensions = $dim
        $Metric.Value = $connectedPlayers

        ### Write the metric data to the CloudWatch service
        Write-CWMetricData -Namespace VRisingDedicatedServer -MetricData $Metric
    }
#endregion Functions

#region Main
    if($logStreamName){
        Write-Host "Beginning to get connected players for server $ServerName | Results will be parsed from CW log group $logGroupName and stream $logStreamName"
    }elseif($logFilePath){
        Write-Host "Beginning to get connected players for server $ServerName | Results will be parsed from $logfilepath"
    }
    Write-ConnectedVRisingPlayersCloudWatch -isCWLogFile -LogStreamName $LogStreamName -LogGroupName $logGroupName -serverName $ServerName
    Write-Host "$(Get-Date) Operation finished"
#endregion Main