#region Variables
    $Region = "us-west-2"
    $IAMRoleName = "VRisingDedicatedServerMonitoringRole"
    $ScheduleExpression = "rate(5 minutes)"
#endregion Variables

#region Functions
    function Publish-MonitoringLambdas{
        param(
            [Parameter(Mandatory=$true)]
            [String]$Name,
            [String]$Region,
            [String]$IAMRoleName
        )

        #Publish Lambda
        $publishPSLambdaParams = @{
            Name = $Name
            ScriptPath = ".\$($Name)\$($Name).ps1"
            Region = $Region
            IAMRoleArn = $IAMRoleName
        }
        Publish-AWSPowerShellLambda @publishPSLambdaParams

        #Test and view results
        #To see all CWL groups: get-cwlloggroup
        $functionName = "Get-ConnectedVRisingPlayers"
        $logGroupName = "/aws/lambda/$Name"
        $results = Invoke-LMFunction -FunctionName $Name -InvocationType Event
        Write-Host "Lambda invocation status is $($results.httpstatuscode)"
        $logs = Get-CWLFilteredLogEvent -LogGroupName $LogGroupName
        $logs.events
    }
#endregion Functions

#region TrustPolicy
$trustPolicy = '{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "lambda.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}'
#endregion TrustPolicy

#region Main
    New-IAMRole -RoleName $IAMRoleName -AssumeRolePolicyDocument $TrustPolicy
    Register-IAMRolePolicy -RoleName $IAMRoleName -PolicyArn "arn:aws:iam::aws:policy/CloudWatchFullAccess"
    Register-IAMRolePolicy -RoleName $IAMRoleName -PolicyArn "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
    $Name = "Get-ConnectedVRisingPlayers"
    Publish-MonitoringLambdas -Name $Name -Region $Region -IAMRoleName $IAMRoleName
    Write-EVBRule -Name "$Name-Rule" -Description "Event bridge rule for Lambda function $Name, runs on a regular schedule of: $ScheduleExpression" -ScheduleExpression $ScheduleExpression
    $FunctionConfig = Get-LMFunctionConfiguration -FunctionName $Name
    $FunctionArn = New-Object -TypeName Amazon.EventBridge.Model.Target
    $FunctionArn.Arn = $FunctionConfig.FunctionArn
    $FunctionArn.Id = $FunctionConfig.RevisionId
    Write-EVBTarget -Rule "$Name-Rule" -Target $FunctionArn
    $Name = "Get-VrisingServerHealthCheck"
    Publish-MonitoringLambdas -Name $Name -Region $Region -IAMRoleName $IAMRoleName
    Write-EVBRule -Name "$Name-Rule" -Description "Event bridge rule for Lambda function $Name, runs on a regular schedule of: $ScheduleExpression" -ScheduleExpression $ScheduleExpression
    $FunctionConfig = Get-LMFunctionConfiguration -FunctionName $Name
    $FunctionArn = New-Object -TypeName Amazon.EventBridge.Model.Target
    $FunctionArn.Arn = $FunctionConfig.FunctionArn
    $FunctionArn.Id = $FunctionConfig.RevisionId
    Write-EVBTarget -Rule "$Name-Rule" -Target $FunctionArn
#endregion Main