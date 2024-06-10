 
function Get-HexASNfromDate {

    [CmdletBinding()]

    param (
        [Parameter(Mandatory,ValueFromPipeline)]
        [DateTime]$DateTime,
        [Switch]$Generalized=$false
    )

    if ($Generalized) {
        $pattern = "yyyyMMddhhmmssZ"
    } else {
        $pattern = "yyMMddhhmmssZ"
    }
    $iso8601 = $DateTime.ToUniversalTime().ToString($pattern)
    $enc = [System.Text.Encoding]::ASCII
    $bytes = $enc.GetBytes($iso8601)
    # add 18 0F for GeneralizedTime
    # add 17 0D for UTCTime
    $dateHex = ($bytes|ForEach-Object ToString X2) -join ' '
    if ($Generalized) {
        return "18 0F " + $dateHex
    } else {
        return "17 0D " + $dateHex
    }

}

function Get-CrlKeyId {

    [CmdletBinding()]

    param (
        [Parameter(Mandatory,ValueFromPipeline)]
        [string]$Path
    )

    if (Test-Path $Path) {
        # Dirty, but it's the only option as PS doesn't understand CRLs
        $string = (certutil -dump $Path | Out-String)
        $string -match ' *KeyID=(?<KeyId>[0-9a-fA-F]+)' | Out-Null
        if ($Matches) {
            return $Matches.KeyId
        } else {
            throw [System.Management.Automation.ItemNotFoundException] "KeyID not found in CRL file"
        }
    } else {
        throw [System.IO.FileNotFoundException] "$Path not found."
    }
}

function Set-CrlLifecycle {

    [CmdletBinding()]

    param (
        [Parameter(Mandatory,ValueFromPipeline)]
        [string]$InPath,

        [Parameter(Mandatory)]
        [string]$OutPath,

        [DateTime]$ThisUpdate=[DateTime](get-date -format 'dd MMMM yyyy 00:00Z'),

        [ValidatePattern("[0-9]+:[0-9]+")][string]$NextUpdateOffset="0:0",

        [ValidatePattern("[0-9]+:[0-9]+")][string]$NextPublishOffset="0:0"
    )

    $NextPublishArray = $NextPublishOffset.Split(':')
    $NextPublish = $ThisUpdate.AddDays($NextPublishArray[0]).AddHours($NextPublishArray[1])

    $hex =  Get-HexASNfromDate $NextPublish -Generalized

    $key = Get-CrlKeyId $inFile

    $iniFile = New-TemporaryFile

    $ini = @"
[Extensions]
1.3.6.1.4.1.311.21.4=`"{hex}$hex`"
"@

    $ini | Out-File $iniFile

    $Validity = ($ThisUpdate.ToString('dd MMMM yyyy hh:mmZ+')) + $NextUpdate

    $rtn = C:\Windows\System32\CertUtil.exe -cert $key -silent -f -sign $InPath $OutPath $Validity `@$iniFile

    if ($LASTEXITCODE -ne 0) {
        #write-host 'Fail'
    } else {
        # write-host 'Success'
    }

    Remove-Item $iniFile

}

Set-CrlLifecycle -InPath C:\test.crl -OutPath C:\long.crl -NextPublishOffset "1:0" -NextUpdateOffset "6:0" 
