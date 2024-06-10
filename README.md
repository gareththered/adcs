# ADCS

Scripts to help with ADCS.

They will all need tweaking before use...

## CRL Extend (and installer)

The `crl-extend.ps1` script generates a series of CRLs with extending validity periods.  It should be ran regularly by the same service accout as the CA service (`SYSTEM`) to create a folder of extended CRLs.  A wise option would be to run it under an event launched scheduled task.  Event ID 4872 would be a good candidate as it is logged each time the CA's internal scheduler issues a fresh CRL.  This would result in a folder of extending CRLs, refreshed each time the CA issues a CRL.

The `install-crl-extend.ps1` script creates the scheduled task and registers the event source.

## CRL Extend with NextPublish

Just a proof-of-concept at the moment.  `certutul.exe -sign` by default signs a CRL without the Microsoft NextPublish extension.  This script adds a configurable NextPublish extension to the CRLs in the same way as the CA does.
