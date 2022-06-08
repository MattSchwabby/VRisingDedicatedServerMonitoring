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
#Requires -Modules @{ModuleName='PackageManagement';ModuleVersion='1.4.7'}
#Requires -Modules @{ModuleName='PowerShellGet';ModuleVersion='2.2.5'}
#Requires -Modules @{ModuleName='AWS.Tools.Installer';ModuleVersion='1.0.2.4'}
#Requires -Modules @{ModuleName='AWS.Tools.Common';ModuleVersion='4.1.99'}
#Requires -Modules @{ModuleName='AWS.Tools.Cloudwatch';ModuleVersion='4.1.99'}

# Uncomment to send the input event to CloudWatch Logs
# Write-Host (ConvertTo-Json -InputObject $LambdaInput -Compress -Depth 5)

#region Variables
    $ServerName = "V Rising Dedicated Server"
    $URI = "https://api.steampowered.com/ISteamApps/GetServersAtAddress/v0001?addr=192.168.0.1:9877"
#endregion Variables

#region  Import
    Import-Module PackageManagement
    Import-Module PowerShellGet
    Import-Module AWS.Tools.Installer
    Import-Module AWS.Tools.Common
    Import-Module AWS.Tools.Cloudwatch
#endregion Import

#region Main
    Write-Host "Starting Health check for $ServerName | GET $URI"
    $result = Invoke-WebRequest -URI $URI
    $content = $result.Content | ConvertFrom-Json
    Write-Host "Received $($content.response.Success)"
    Write-Host "Server address: $($content.response.servers.addr)"
    Write-Host "steamID: $($content.response.servers.steamid)"
    Write-Host "gamedir: $($content.response.servers.gamedir)"
    Write-Host "gameport: $($content.response.servers.gameport)"
    Write-Host "Server health status is $($content.response.success)"
    if($content.response.success){
        Write-Host "Server health check for $ServerName succeeded)"
        $Metric = New-Object -TypeName Amazon.CloudWatch.Model.MetricDatum
        
        $dim=[Amazon.CloudWatch.Model.Dimension]::new()
        $dim.Name="ServerName"
        $dim.Value="$ServerName"
        $Metric.Timestamp = [DateTime]::UtcNow
        $Metric.MetricName = 'HealthCheck'
        $metric.Dimensions = $dim
        $Metric.Value = 1

        ### Write the metric data to the CloudWatch service
        Write-CWMetricData -Namespace VRisingDedicatedServer -MetricData $Metric
        }else{
            Write-Host "server health check failed"
            $Metric = New-Object -TypeName Amazon.CloudWatch.Model.MetricDatum
            
            $dim=[Amazon.CloudWatch.Model.Dimension]::new()
            $dim.Name="ServerHealth"
            $dim.Value="$ServerName"
            $Metric.Timestamp = [DateTime]::UtcNow
            $Metric.MetricName = 'HealthCheck'
            $metric.Dimensions = $dim
            $Metric.Value = 0

            ### Write the metric data to the CloudWatch service
            Write-CWMetricData -Namespace VRisingDedicatedServer -MetricData $Metric
    }
    Write-Host "$(Get-Date) Completed Server health check for $ServerName"
#endregion Main