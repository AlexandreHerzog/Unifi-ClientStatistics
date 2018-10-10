# SOURCES
#
# https://github.com/Art-of-WiFi/UniFi-API-browser
# 


cd [YOUR_DATA_FOLDER]

# Unifi username and password allowed to connect to the admin interface - doesn't need to be an admin, can be a standard user
$apiUser = "[UNIFI_USERNAME]"
$apiPassword = "[UNIFI_PASSWORD]"
$apiUrl = "https://unifi:8443"
$apsAliases = @{
    "25:11:22:33:44:55" = "AP First Floor"
    "25:11:22:33:44:66" = "AP Second Floor"
}
$queryInterval = 180 # Makes the API call every 3 minutes
$unifiExportFile = "UnifiStats.csv"

# Disable SSL checks as the provided certificate by Unifi isn't valid
add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Ssl3, [Net.SecurityProtocolType]::Tls, [Net.SecurityProtocolType]::Tls11, [Net.SecurityProtocolType]::Tls12


# Login
while ($true) {
    $headers = @{}
    $headers.Add("Referer",($apiUrl + "/login"))
    $r = Invoke-WebRequest -uri ($apiUrl + "/api/login") -Method Post -Headers $headers -SessionVariable apiSession -Body (@{
            "username" = $apiUser
            "password" = $apiPassword
            } | ConvertTo-Json)

    # Sites
    #$statsResponse = Invoke-WebRequest -uri ($apiUrl + "/api/s/default/stat/device") -WebSession $apiSession
    #$statsContent = $statsResponse.content | ConvertFrom-Json


    $staResponse = Invoke-WebRequest -uri ($apiUrl + "/api/s/default/stat/sta") -WebSession $apiSession
    $staContent = $staResponse.content | ConvertFrom-Json

    $staContent.data | % {
        $result = [pscustomobject][ordered]@{
            "Date" = $staResponse.Headers["Date"]
            "Hostname" = $_.hostname
            "Name" = $_.name
            "Signal" = $_.signal
            "Noise" = $_.noise
            "Uptime" = $_.uptime
            "TX rate" = $_.tx_rate
            "RX rate" = $_.rx_rate
            "RSSI" = $_.rssi
            "AP" = $_.ap_mac
            "AP alias" = $aps[$_.ap_mac]
            "ESSID" = $_.essid
        }
        write-host $result
        Export-Csv -InputObject $result -Append -NoTypeInformation $unifiExportFile
    }

    sleep $queryInterval
}
