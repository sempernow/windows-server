## * Browsers (Chrome) having "Secure DNS" enabled bypassed local DNS,
##   and so fail by: DNS_PROBE_FINISHED_NXDOMAIN error. 
## * This script adds root CA certificate (ADCS) to Windows Trust Store 
##   of LocalMachine (certlm) at "Trusted Root Certificate Authorities/Certificates" folder
##   to fix browser's CRYPT_E_REVOCATION_OFFLINE error:
Import-Certificate -FilePath "lime-dc1-ca.crt" -CertStoreLocation Cert:\LocalMachine\Root
