$CustomerID = "" #attained via N-Able > Administration > customers
$token = "" #Attained via N-able > Selecting the company in top left > actions > Download agent/probe > get registration token
Invoke-WebRequest -Uri "https://control.techary.com/download/current/winnt/N-central/WindowsAgentSetup.exe" -outfile C:\WindowsAgentSetup.exe
C:\WindowsAgentSetup.exe /s /v" /qn CUSTOMERID=$CustomerID REGISTRATION_TOKEN=$Token CUSTOMERSPECIFIC=1 SERVERPROTOCOL=HTTPS SERVERADDRESS=control.techary.com SERVERPORT=443"
