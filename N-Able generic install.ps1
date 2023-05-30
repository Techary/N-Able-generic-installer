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
                uri = "https://control.techary.com/download/current/winnt/N-central/WindowsAgentSetup.exe"
                outfile = "C:\temp\WindowsAgentSetup.exe"
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

            C:\temp\WindowsAgentSetup.exe /S /v" /qn CUSTOMERID=$CustomerID CUSTOMERSPECIFIC=1 REGISTRATION_TOKEN=$Token SERVERPROTOCOL=HTTPS SERVERADDRESS=control.techary.com SERVERPORT=443 "

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
write-host $(Get-Date -Format u) "[Information] Setting customerID"
$script:CustomerID = "" #attained via N-Able > Administration > customers
if ($null -ne $CustomerID)
    {

        write-host $(Get-Date -Format u) "[Information] ID set to $customerID"

    }
write-host $(Get-Date -Format u) "[Information] Setting token"
$script:token = "" #Attained via N-able > Selecting the company in top left > actions > Download agent/probe > get registration token
if ($null -ne $token)
    {

        write-host $(Get-Date -Format u) "[Information] Token set to $token"

    }
get-rmminstaller
if (test-path $RMMParams.outfile)
    {

        write-host $(Get-Date -Format u) "[Information] RMM downloaded succesfully, attempting install..."

    }
invoke-rmminstaller
Stop-Transcript
