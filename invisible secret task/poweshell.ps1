# Get user input for the new username and password
$username = Read-Host "Enter the new username"
$password = Read-Host "Enter the new password" -AsSecureString

# Convert the secure string to plain text
$passwordPlainText = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($password))

# Define the connection strings to replace
$connectionStrings = @{
    'ConnectionString' = 'Server=SQLIACPRD;Database=T1BPPV;User Id={0};Password={1};' -f $username, $passwordPlainText
#     'PermitVisionConnectionString' = 'Server=SQLIACPRD;Database=T1BPPVP;User Id={0};Password={1};' -f $username, $passwordPlainText
#     'PermitVisionBlobConnectionString' = 'Server=SQLIACPRD;Database=T1BPBLOB;User Id={0};Password={1};' -f $username, $passwordPlainText
#     'FlocServiceConnectionString' = 'Server=SQLIACPRD;Database=T1BPFLOC;User Id={0};Password={1};' -f $username, $passwordPlainText
}

# Read the contents of the original file
$content = Get-Content -Path "task.ini" -Raw

# Replace the user ID and password in the connection strings
foreach ($key in $connectionStrings.Keys) {
    $content = $content -replace "$key\s*=.*;", "$key = $($connectionStrings[$key])"
}

# Save the modified content back to the file
$content | Set-Content -Path "connectionstring.ini"