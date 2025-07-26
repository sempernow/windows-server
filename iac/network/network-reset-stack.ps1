# Reset TCP/IP stack
netsh int ip reset

# Reset Winsock
netsh winsock reset

# Reset the IP configuration
ipconfig /release
ipconfig /renew

# Clear DNS cache
ipconfig /flushdns

# Reset Windows Firewall to default settings (optional, if firewall issues are suspected)
netsh advfirewall reset
