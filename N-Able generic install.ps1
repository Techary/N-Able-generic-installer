Param(
    [Parameter(Mandatory=$True)][String]$script:CustomerID,
    [Parameter(Mandatory=$True)][string]$script:token,
    [Parameter(Mandatory=$True)][string]$script:serveraddress,
    [Parameter(Mandatory=$True)][String]$script:uri,
    [Parameter(Mandatory=$True)][String]$script:outfile
)

Start-Transcript "C:\temp\rmminstall.log"

function Get-InstallStatus {

    if (get-service | where {$_.displayname -like "*n-able*"})
        {

            write-host $(Get-Date -Format u) "[Information] N-Able already installed, exiting..."
            Stop-Transcript
            exit

        }
    else
        {


        }

}

function Get-RMMInstaller {

    try
        {

            $script:RMMParams = @{
                uri = $script:uri
                outfile = $script:outfile
            }
            $ProgressPreference = 'SilentlyContinue'
            Invoke-WebRequest @RMMParams -ErrorAction stop

        }
    catch
        {

            if ($null -eq $DownloadErrorcount)
                {
                    write-host $(Get-Date -Format u) "[Warning] Unable to download RMM, trying again..."
                    $DownloadErrorcount++
                    get-rmminstaller
                }
            else
                {

                    write-host $(Get-Date -Format u) "[Warning] Unable to download RMM" $error.exception[0]
                    Stop-Transcript
                    exit

                }

        }

}

function Invoke-RMMInstaller {

    try
        {

            C:\temp\WindowsAgentSetup.exe /S /v" /qn CUSTOMERID=$CustomerID CUSTOMERSPECIFIC=1 REGISTRATION_TOKEN=$Token SERVERPROTOCOL=HTTPS SERVERADDRESS=$serveraddress SERVERPORT=443 "

        }
    catch
        {

            if ($null -eq $InstallError)
                {

                    write-host $(Get-Date -Format u) "[Warning] Unable to install RMM, trying again..."
                    $InstallError++
                    invoke-rmminstaller

                }
            else
                {

                    write-host $(Get-Date -Format u) "[Warning] Unable to install RMM" $error.exception[0]
                    Stop-Transcript
                    exit

                }

        }

}

Get-InstallStatus
write-host $(Get-Date -Format u) "[Information] ID set to $customerID"
 write-host $(Get-Date -Format u) "[Information] Token set to $token"
get-rmminstaller
if (test-path $RMMParams.outfile)
    {

        write-host $(Get-Date -Format u) "[Information] RMM downloaded succesfully, attempting install..."

    }
invoke-rmminstaller
Stop-Transcript
