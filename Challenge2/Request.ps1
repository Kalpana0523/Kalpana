$response = Invoke-RestMethod -Headers @{"Metadata"="true"} -Method GET -Proxy $Null -Uri "http://169.254.169.254/metadata/instance?api-version=2021-02-01" 

$respJSON = $response | ConvertTo-Json -Depth 64

$respJSON