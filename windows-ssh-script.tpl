add-content -path ~/.ssh/AzureJenkinsKey1 -value @'

Host ${hostname}
  HostName ${hostname}
  User ${user}
  IdentityFile ${identityfile}
'@