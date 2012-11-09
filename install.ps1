if($PSVersionTable.PSVersion.Major -lt 2) {
    Write-Warning "posh-jenkins requires PowerShell 2.0 or better; you have version $($Host.Version)."
    return
}

[System.Reflection.Assembly]::LoadWithPartialName("System.Web") | out-null

if ($args.length -match 0) {
    Throw (New-Object system.ArgumentNullException -arg "url") 
}

$jenkinsUrl = $args[0];

function ConvertTo-UrlEncodedPath([string]$dataToConvert)
{
    begin {
        function EncodeCore([string]$data) { return [System.Web.HttpUtility]::UrlPathEncode($data) }
    }
    process { if ($_ -as [string]) { EncodeCore($_) } }
    end { if ($dataToConvert) { EncodeCore($dataToConvert) } }
}

<#
.SYNOPSIS
Instructs Jenkins to build the specified job with the default parameters.
.DESCRIPTION
Instructs Jenkins to build the specified job with the default parameters.
.PARAMETER job
The name of the job, as displayed using Jenkins-Jobs.
.EXAMPLE
PS C:\> Jenkins-Build "Job Name"
#>
function Jenkins-Build($job)
{
    $encoded = ConvertTo-UrlEncodedPath($job)
	$url = $jenkinsUrl + "job/" + $encoded + "/buildWithParameters"

	$req = [System.Net.WebRequest]::Create($url)
	$req.Method ="GET"
	$req.ContentLength = 0
	$resp = $req.GetResponse()
    
    return $resp.StatusCode
}

Set-Alias jb Jenkins-Build

<#
.SYNOPSIS
Lists the jobs configured on the Jenkins server, colouring each depending on status.
.DESCRIPTION
Lists the jobs configured on the Jenkins server, colouring each depending on status.
.EXAMPLE
PS C:\> Jenkins-Jobs
#>
function Jenkins-Jobs()
{
    $url = $jenkinsUrl + "api/xml?tree=jobs[name,color,lastBuild[building,result]]"

	$client = New-Object System.Net.WebClient
    $bytes = $client.DownloadData($url)
    $response = [System.Text.Encoding]::ASCII.GetString($bytes)
    $xml = [xml]($response)
    $string = $xml.hudson.job | Select-Object @{Name="Name"; Expression={$_.name} }, @{Name="LastResult"; Expression={$_.lastBuild.result}} | Format-Table Name, @{Name="Last Result"; Expression={$_.LastResult}} -autosize | Out-String
    $array = $string.Split("`n", [StringSplitOptions]::RemoveEmptyEntries)
    $array | foreach {
        if($_ -match "SUCCESS"){
            Write-Host $_ -ForegroundColor "cyan";
        } elseif ($_ -match "UNSTABLE") {
            Write-Host $_ -ForegroundColor "yellow";
        } elseif ($_ -match "FAILURE") {
            Write-Host $_ -ForegroundColor "red";
        } else {
            Write-Host $_
        }
    }
}

Set-Alias jj Jenkins-Jobs

<#
.SYNOPSIS
Displays various details about the Jenkins server.
.DESCRIPTION
Displays various details about the Jenkins server.
.EXAMPLE
PS C:\> Jenkins-Info
#>
function Jenkins-Info()
{
    $url = $jenkinsUrl + "api/xml"

	$client = New-Object System.Net.WebClient
    $bytes = $client.DownloadData($url)
    $response = [System.Text.Encoding]::ASCII.GetString($bytes)
    $xml = [xml]($response)
    
    return $xml.hudson
}

Set-Alias ji Jenkins-Info

function script:jenkinsJobs($filter) {
    $url = $jenkinsUrl + "api/xml?tree=jobs[name]"

	$client = New-Object System.Net.WebClient
    $bytes = $client.DownloadData($url)
    $response = [System.Text.Encoding]::ASCII.GetString($bytes)
    $xml = [xml]($response)
    return $string = $xml.hudson.job | foreach { $_.name } | where { $_ -like "$filter*" } | foreach {
        if ($_ -like '* *') {
            """$_"""
        } else {
            $_
        }
    }
}

function script:expandJenkinsBuildAlias($cmd, $rest) {
    return "jb $cmd$rest"
}

function JenkinsBuildTabExpansion($lastBlock) {
    if($lastBlock -match '^$jb (?<job>\S+)$') {
        $lastBlock = expandJenkinsBuildAlias $Matches['cmd'] $Matches['args']
    }

    switch -regex ($lastBlock) {
        '^jb.* (?<names>\S*)$' {
            jenkinsJobs $matches['names']
        }
    }

    jenkinsJobs $matches['cmd'] $matches['op']
}

if (Test-Path Function:\TabExpansion) {
    Rename-Item Function:\TabExpansion JenkinsTabExpansionBackup
}

function TabExpansion($line, $lastWord) {
    $lastBlock = [regex]::Split($line, '[|;]')[-1].TrimStart()
    
    switch -regex ($lastBlock) {
        # Execute Jenkins-Build tab completion for all Jenkins-Build commands
        'jb (.*)' { JenkinsBuildTabExpansion $lastBlock }
        
        # Fall back on existing tab expansion
        default { if (Test-Path Function:\JenkinsTabExpansionBackup) { JenkinsTabExpansionBackup $line $lastWord } }
    }
}