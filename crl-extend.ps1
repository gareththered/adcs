###################################################################
#
# .SYNOPSIS
# Generates extended validity CRLs and stores and stores them in
# a staging directory.
#
# .DESCRIPTION
# This script is scheduled to run every time the CA issues a CRL
# by adding it as a Scheduled Task which is triggered by
# Event ID 4872.  It will create CRLs with names consisting
# of an increasing numerical prefix and the original CRL filename.
# Each CRL will also be resigned with exponentially extending
# validity periods, as defined in the extendedByDaysHours array.
# These CRLs are stored in a staging directory for distribution.
# It also copies the CA certificate from CertEnroll to the staging
# directory, renaming it in the process.
#
# Author: Gareth Williams <g.williams@dxc.com>
#
###################################################################

# The name of the CA as specified in the AIA extension (less prefix and extension)
# If the AIA extension in the CA Properties has %3 for this, then the CN of the CA
# should be placed here.
$tgtCAName = "WinTest-Issuing-CA1"

# The staging directory where CRLs and certificates are saved
$outDir = "C:\SrcStaging"

# Where certificates and CRLs are sourced - no need to change this
$CertEnroll = "$env:windir\System32\CertSrv\CertEnroll"

#$extendByDaysHours = @("1:12","2:00","4:00","8:00","15:00","29:00")
$extendByDaysHours = @("0:02","0:03","0:04")

# The source name used with event logs.
# WARNING: This source must be created before this script is ran!
$eventSrc = "CRL Distribution"

#################################### Below here be dragons! ############################################

# Create the output directory
mkdir -force $outDir | Out-Null

# Enumerate through each *.crl file in CertErnoll directory
Get-ChildItem -Path $CertEnroll -Filter *.crl | ForEach-Object {

    # With each CRL
    
    # Don't resign original CRL - simply copy it with its new filename (0-????.crl)
    Copy-Item -Force $_.FullName $(Join-Path $outDir 0-$($_.Name))
    
    # $prefix is a counter that is prepended to the output CRL filename
    $prefix = 1

    # $success counts the number of successful re-signs (for the Eventlog)
    $success = 0

    # Loop through all the values in the array in turn
    ForEach ($period in $extendByDaysHours) {
        
        # TODO: Must add "-Cert <serial|hash|> -Silent" here in prep for multiple keys after renewal.
        # TODO: The "hash" is extractable from the source CRL, so may be a good candidate...
        # Create an output CRL filename from output dir, prefix and original name
        # Resign each with a extended validity period
        $rtn = C:\Windows\System32\CertUtil.exe -Silent -f `
                                                -Sign $_.FullName $(Join-Path $outDir $prefix-$($_.Name)) `
                                                $period
        # Check certutil's exit code
        if ($LASTEXITCODE -ne 0) {
            Write-EventLog  -LogName Application -Source $eventSrc -Category 0 -EntryType Error `
                -EventId 1201 -Message "Certutil reported the following error while resigning the CRL to $period (dd:hh)`n`n`t$rtn.s`n"
        }
        else {
            $success++
        }

        # Increment prefix counter
        $prefix++
    }
    Write-EventLog  -LogName Application -Source $eventSrc -Category 0 -EntryType Information `
                    -EventId 1001 -Message "Extended $success/$($prefix -1) certificates.`n"
}

###################################################################
#
# This section copies any new/updated certificates from
# CertEnroll to the same folder as the extended CRLs above
#
###################################################################

# Enumerate through each certificate in the source directory
# The regex captures the optional certificate suffix and the file extension.
# E.g for ExampleCA1(2).cer the capture is "(2).cer"
Get-ChildItem $CertEnroll | Where-Object {$_.Name -Match '^.*?((?:\(\d\))?\.(?:cer|crt|pem))$'} | ForEach-Object {
    
    # With each certificate

    # Join the output directory, the CA name and the suffix to create the target certificate name
    $tgtFile = Join-Path $outDir $($tgtCAName + $Matches[1])

    # If the destination doesn't exists, or the hash of each file is different
    If (-not (Test-Path $tgtFile) -or (Get-FileHash $_.FullName).Hash -ne (Get-FileHash $tgtFile).Hash) {
        # copy the source over
        Copy-Item $_.FullName $tgtFile
        Write-EventLog  -LogName Application -Source $eventSrc -Category 0 -EntryType Information `
                        -EventId 1002 -Message "A new CA certificate has been copied to the staging directory:`n`n`tCertificate:`t$_`n"
    }
}
