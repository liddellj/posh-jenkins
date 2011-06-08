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
    $url = $jenkinsUrl + "api/xml"

	$client = New-Object System.Net.WebClient
    $bytes = $client.DownloadData($url)
    $response = [System.Text.Encoding]::ASCII.GetString($bytes)
    $xml = [xml]($response)
    $names = $xml.hudson.job | Select-Object name, color | foreach {
        if($_.color -match "blue"){
            Write-Host $_.name -ForegroundColor "cyan";
        } elseif ($_.color -match "yellow") {
            Write-Host $_.name -ForegroundColor "yellow";
        } else {
            Write-Host $_.name -ForegroundColor "white";
        }
    }
    
    return $names
}

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