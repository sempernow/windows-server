# WS2019 : AD CS

### IIS : Web Enrollment Page : `/certsrv`

This is the __certificate server__ through which authenticated users request and recieve TLS certificates. Its FQDN is that of the Domain Controller hosting it (e.g., `dc1.lime.lan`).

- [Microsoft Active Directory Certificate Services  --  lime-DC1-CA](https://dc1.lime.lan/certsrv/)
    - CA Name: `lime-DC1-CA` (`CN`)
    - __`https://dc1.lime.lan/certsrv/`__

## Tasks

1. Request a certificate
    - "[User Certificate](https://dc1.lime.lan/certsrv/certrqbi.asp?type=0)"
        - Of the authenticated user only.
    - "Or, submit an [advanced certificate request](https://dc1.lime.lan/certsrv/certrqxt.asp)"
1. View the status of a pending certificate request
1. Download a CA certificate, certificate chain, or CRL
    - `certcrl.crl` : CRL (base or delta per select)
    - `certnew.cer` : CA certificate
    - `certnew.p7b` : Fullchain CA certificate

## Download options

- `*.cer` : Certificate of either encoding method
    - Per checkbox:
        * DER (binary)
        * Base 64 (PEM)
- `*.p7b` : Fullchain Certificate
- `*.crl` : CRL (base or delta per select)

The fullchain, PEM encoded version prepends two lines of certificate metadata, "`subject=...`" and "`issuer=...`" to each certificate block:

```plaintext
subject=C = ...OU = ops, CN = kube.lime.lan, ...
issuer=DC = lan, DC = lime, CN = lime-DC1-CA
-----BEGIN CERTIFICATE-----
...
```

The fullchain may include that of the root CA, 
which should be omitted from end-entity TLS certificates 
for security. 

That is, clients should validate the server's certificate
using the client-side trust store. Until then, 
the client should treat that certificate as merely a server's claim.


## CRL (Certificate Revocation List)

Download from ADCS `certsrv` @ https://dc1.lime.lan/certsrv/certcarc.asp

@ `Ubuntu [13:28:32] [1] [#0] /s/DEV/devops/infra/windows-server/iac/adcs/ca/root/v0.0.1`

```bash
## Get CRL from 
☩ openssl crl -inform PEM -text -noout -in lime-DC1-CA-certcrl.crl
```
- See `crl()` of `make.recipes.sh`
```ini
Certificate Revocation List (CRL):
        Version 2 (0x1)
        Signature Algorithm: sha256WithRSAEncryption
        Issuer: DC = lan, DC = lime, CN = lime-DC1-CA
        Last Update: Jul 20 09:54:16 2025 GMT
        Next Update: Jul 27 22:14:16 2025 GMT
        CRL extensions:
            X509v3 Authority Key Identifier: 
                55:8A:C3:DD:18:5D:7A:EA:82:47:68:98:C8:D4:4E:BB:09:DC:85:86
            1.3.6.1.4.1.311.21.1: 
                ...
            X509v3 CRL Number: 
                97
            1.3.6.1.4.1.311.21.4: 
                .
250727100416Z
            X509v3 Freshest CRL: 
                Full Name:
                  URI:ldap:///CN=lime-DC1-CA,CN=dc1,CN=CDP,CN=Public%20Key%20Services,CN=Services,CN=Configuration,DC=lime,DC=lan?deltaRevocationList?base?objectClass=cRLDistributionPoint
            1.3.6.1.4.1.311.21.14: 
                0..0...........ldap:///CN=lime-DC1-CA,CN=dc1,CN=CDP,CN=Public%20Key%20Services,CN=Services,CN=Configuration,DC=lime,DC=lan?certificateRevocationList?base?objectClass=cRLDistributionPoint
Revoked Certificates:
    Serial Number: 1F000000064F9FE093DA77F9A9000000000006
        Revocation Date: Jun  1 01:52:00 2025 GMT
...
```
```bash
## Get serial number of a certificate:
☩ openssl x509 -noout -serial -in lime-DC1-CA-fullchain.pem
serial=42FBFBF0C52E86AE4B9C1E8CB6040AB2
```

---



### "Enterprise Root CA" v. "Enterprise Subordinate CA"

In AD CS, the title of (IIS) web-enrollment page is "Microsoft Active Directory Certificate Services – <CA-Name>", showing whatever CA is installed on that particular machine. In our case, we installed AD CS role as "Enterprise Root CA" (`CN=lime-DC1`), so the only authority (`CA`) that the built-in web UI can reach is "`lime-DC1-CA`" (the root). 

Creating a __Subordinate CA__ certificate using the built-in "Subordinate Certification Authority" (SubCA) template does not, by itself, change which service the web UI is pointing at; it simply creates a signed certificate that __*could* become a separate CA if on a second machine__ (IP/hostname) having that certificate bound to it.

1. **One CA instance per server.**
   Each Windows host can only run a single AD CS instance. The "Add Roles and Features → Active Directory Certificate Services → Certification Authority," the wizard asks you to choose a CA Type. We chose "__Enterprise Root CA__," so that machine became the root. At that point, the IIS page `https://<this-server>/certsrv` is configured to offer certificates from that Root CA.

2. **Creating a Subordinate CA certificate isn’t the same as installing a second CA role.**
   When we duplicated or directly used the built-in "Subordinate Certification Authority" (SubCA) template to generate a CSR, we ended up with a certificate (`CN=LIME-ISSUING-CA`) that *could* be used by another CA service. But until we actually spin up a second AD CS service (as a "__Enterprise Subordinate CA__") and __import this signed cert into it__, there is no "`LIME-ISSUING-CA`" service for the web UI to display. In other words:

   * The **template** ("Subordinate Certification Authority") is just a certificate template.
   * We used it to produce a "Subordinate CA" certificate from our Root.
   * But we have *not* yet installed a CA service (role) that *hosts* that subordinate-signed certificate.

As a result, the only running CA service is still the root, even though we hold a Subordinate CA certificate in our store, so the enroll page reads "Microsoft Active Directory Certificate Services – lime-DC1-CA"


### How to use the Subordnate CA (`LIME-ISSUING-CA`) as the issuing CA

For the intermediate CA (`CN=LIME-ISSUING-CA`) to be the one signing all end-entity TLS certificates, 
it must be installed onto a __*second* CA instance__. The usual workflow is:

1. **Prepare a second Windows host (or a second IP/hostname).**
   You cannot install two AD CS CA roles on the same computer name or IP. In a tiny air-gap network, that usually means either:

   * Spinning up a second Windows VM (joined to the same domain) and giving it a unique hostname (e.g. "lime-issuing"), or
   * Giving your existing server a second network interface with its own distinct DNS name (and then installing a second AD CS role bound to that name).

2. **On that second host, install AD CS as a "Subordinate CA."**

   * On Windows Server 2019 (lime-issuing), run **Server Manager → Add Roles and Features → Active Directory Certificate Services → Certification Authority**.
   * When prompted for CA Type, choose **"Enterprise Subordinate CA."**
   * The wizard will generate a new RSA keypair and then export a CSR file (e.g. `lime-issuing-CA.req`).

3. **Submit that CSR to your Root CA (lime-DC1-CA).**

   * On lime-issuing, complete the wizard up to "Generate the certificate request to file."
   * Copy `lime-issuing-CA.req` over to lime-DC1.
   * On lime-DC1, open **Certification Authority → Right-click → All Tasks → Submit new request** and pick that `.req`.
   * Approve/sign it under your Root CA and then export the resulting `.cer` file (or use the web UI to "Download certificate").

4. **Finish the Subordinate CA setup on lime-issuing.**

   * Back on lime-issuing, point the AD CS installer to the signed subordinate certificate (e.g. `lime-issuing-CA.cer`) and to the Root CA’s chain.
   * The wizard will import both certificates into the local CA database. Now lime-issuing is running as an Enterprise Subordinate CA, and its web-enroll endpoint (`https://lime-issuing/certsrv`) will show up as "Microsoft Active Directory Certificate Services – LIME-ISSUING-CA."

5. **Point all users/clients at the Subordinate CA for day-to-day certificate requests.**

   * For any new "Request a certificate" via web UI, they would browse to `https://lime-issuing/certsrv` (or use Group Policy auto-enrollment) instead of the Root CA.
   * That way, `LIME-ISSUING-CA` issues leaf certificates (e.g. TLS certs for your web servers, etc.), and the end-entity certificates carry a chain → \[Subordinate: `LIME-ISSUING-CA`] → \[Root: `lime-DC1-CA`].

---

### What the trust bundle should look like

Once `LIME-ISSUING-CA` is properly installed and issuing certificates, every client (or service) that needs to trust a server certificate from `LIME-ISSUING-CA` must have:

1. **The Root CA certificate (`lime-DC1-CA`) in their Trusted Root store**, and
2. **The Subordinate CA certificate (`LIME-ISSUING-CA`) in their Intermediate CA store** (or in one combined chain file, depending on the application).

When you export the Subordinate CA certificate (e.g. from the CA console on lime-issuing), __include the full chain__. For example:

```text
—–BEGIN CERTIFICATE—–  
(Certificate for LIME-ISSUING-CA)  
—–END CERTIFICATE—–  

—–BEGIN CERTIFICATE—–  
(Certificate for lime-DC1-CA)  
—–END CERTIFICATE—–
```

You can then import that two-cert bundle (ordered \[subordinate → root]) into any appliance or service you want to trust. That ensures that when a TLS client sees a server cert signed by LIME-ISSUING-CA, it can build the chain up to the root and succeed.

---

### Summary

* **As long as your server is hosting only the Root CA service**, the web UI at `https://<this-server>/certsrv` will continue to be named "Microsoft Active Directory Certificate Services – lime-DC1-CA."
* **To have "LIME-ISSUING-CA" show up as an issuing CA, you must install a separate AD CS instance** (on its own DNS name/IP) as an *Enterprise Subordinate CA*, import the signed subordinate certificate, and then *use that second host* ([https://lime-issuing/certsrv](https://lime-issuing/certsrv)) for day-to-day enrollment.
* **Once that’s in place**, end-entity TLS certificates are signed by LIME-ISSUING-CA, and clients simply need both the subordinate and root CA certificates in their trust stores (or in a combined chain) to validate any issued certificate.

In short, you do want your Subordinate CA (LIME-ISSUING-CA) to do the actual "leaf" signing and to appear in the trust chain, but in AD CS terms, that means running a *second* CA service (on a separate host or at least a separate DNS name). Only then will the web UI reflect "LIME-ISSUING-CA" instead of the Root CA name.


## Root CA certificate

### UPDATE  

#### v1

__See `rootCA()`__ of __`make.recipes.sh`__ at project root.

And create the Root CA by running: `make rootca` .

This is the domain's root CA and is kept offline. 
AD CS is then provisioned as the "Enterprise Subordinate CA", 
for integration with K8s projctes such as __cert-manager__ 
to handles all things TLS. 

That is, we escape the manual Microsoft/GUI hellscape 
to allow for automated TLS provisioning and renewals, and all else by DevOps methods.

Then add AD CS role to the WinSrv2019 host, 
creating an Enterprise Subordinate CA. 

See [__Enterprise Subordinate CA setup__](https://chatgpt.com/share/6883da02-1484-8009-88da-1282f41337b8)

#### v2

Decouple (almost) TLS entirely from the Windows hellscape, 
with cert-manager itself being the subordinate CA signed by the domain's root CA. 

See [__Enterprise Subordinate CA setup__](https://chatgpt.com/share/6883da02-1484-8009-88da-1282f41337b8)


### Create

Create using __Windows Server 2019__ Wizard (GUI) 
whilst adding Roles for __Certificate Authority__ (AD CS).

### Export 

This PowerShell script export that CA certificate to a file:

```powershell
$caName     = "lime-DC1-CA"
$filePath   = "ca-root-dc1.lime.lan.cer"
$cert       = Get-ADObject -LDAPFilter "(cn=$caName)" -SearchBase "CN=Certification Authorities,CN=Public Key Services,CN=Services,$((Get-ADRootDSE).configurationNamingContext)" -Properties "cACertificate"
[System.IO.File]::WriteAllBytes($filePath, $cert."cACertificate"[0])

```

### Add to Windows Trust Store

#### `certutil -addstore root <CA-PEM-FILE-PATH>`

... run as Administrator

```powershell
PS> certutil -addstore root S:\DC01\IaC\adcs\ca-root-dc1.lime.lan.cer
root "Trusted Root Certification Authorities"
Signature matches Public Key
Certificate "lime-DC1-CA" added to store.
CertUtil: -addstore command completed successfully.
```

or

```powershell
PS> Import-Certificate -FilePath "C:\TEMP\ca-root-dc1.lime.lan.cer" -CertStoreLocation Cert:\LocalMachine\Root

   PSParentPath: Microsoft.PowerShell.Security\Certificate::LocalMachine\Root

Thumbprint                                Subject
----------                                -------
ADE65EE0CFB8A8BBD4ADCC4E794C44EC123B4F1B  CN=lime-DC1-CA, DC=lime, DC=lan
```

### Parse / Validate

```bash
☩ tls crt parse ../ca-root-dc1.lime.lan.cer
No extensions in certificate
issuer=DC = lan, DC = lime, CN = lime-DC1-CA
subject=DC = lan, DC = lime, CN = lime-DC1-CA
notBefore=Dec 18 01:58:07 2024 GMT
notAfter=Dec 18 02:08:07 2034 GMT

☩ openssl x509 -noout -text -in ../ca-root-dc1.lime.lan.cer \
    |tee ../ca-root-dc1.lime.lan.cer.parse

Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number:
            42:fb:fb:f0:c5:2e:86:ae:4b:9c:1e:8c:b6:04:0a:b2
        Signature Algorithm: sha256WithRSAEncryption
        Issuer: DC = lan, DC = lime, CN = lime-DC1-CA
        Validity
            Not Before: Dec 18 01:58:07 2024 GMT
            Not After : Dec 18 02:08:07 2034 GMT
        Subject: DC = lan, DC = lime, CN = lime-DC1-CA
        Subject Public Key Info:
            Public Key Algorithm: rsaEncryption
                Public-Key: (4096 bit)
                Modulus:
                    00:ae:9d:...:ff:be:a5
                Exponent: 65537 (0x10001)
        X509v3 extensions:
            X509v3 Key Usage: 
                Digital Signature, Certificate Sign, CRL Sign
            X509v3 Basic Constraints: critical
                CA:TRUE
            X509v3 Subject Key Identifier: 
                55:8A:C3:DD:18:5D:7A:EA:82:47:68:98:C8:D4:4E:BB:09:DC:85:86
            1.3.6.1.4.1.311.21.1: 
                ...
    Signature Algorithm: sha256WithRSAEncryption
    Signature Value:
        45:2e:bc:...:d2:45:4c
```

## Intermediate (Subordinate) CA Certificate

__UPDATE__: Creating and adding a Subordinate CA on the Root CA server is not of much use. 
The Certificate Server binds to __only one CA__. And that (Root v. Subordinate) is chosen when the AD CS role is added (via Wizard). Ours is "Enterprise Root CA", not "Enterprise Subordinate CA".

### Quick Method

Create an Intermediate CA __on an existing Root CA server__, 
without rebuilding the entire PKI:

Note the Root CA is typically managed on its own server, 
which is kept **offline** for security. 

What we're doing here is __acceptable only for air-gapped networks__.

#### 1. Generate the Intermediate CA Certificate


__`sub/v0.0.1` : Success!__

```powershell
# Make the prompt readable
function prompt {
    "$PWD`n> "
}

# Set working dir
net use S: "\\tsclient\S" /persistent:yes
set-location S:\DC01\IaC\adcs\limeSubordinateCA
#net use S: /delete

# Set params
$path = (Get-Location).Path
# UPDATE : We are NOT using this failed template (limeSubordinateCA)
# Rather, we are using Microsoft's (hidden, builtin) template: "SubCA"
$template = "$path\subCA"

$infContent = @'
[Version]
Signature = "$Windows NT$"

[NewRequest]
Subject = "CN=LIME-ISSUING-CA,DC=LIME,DC=LAN"
Exportable = FALSE
KeyLength = 4096
KeySpec = 2
MachineKeySet = TRUE
ProviderName = "Microsoft Software Key Storage Provider"
RequestType = PKCS10
HashAlgorithm = SHA256

[RequestAttributes]
CertificateTemplate = "SubCA"
'@
$infContent | Out-File "$template.inf" -Encoding ASCII

# Generate request (silent mode)
certreq -q -new "$template.inf" "$template.req"

# Submit with verbose logging
certreq -v -submit -config "localhost\$rootCA" "$template.req" "$template.cer"

# Verify
certutil -dump "$template.req"

# Install in the intermediate CA store
certutil -f -addstore "CA" "$template.cer"
# CA "Intermediate Certification Authorities"
# Certificate "LIME-ISSUING-CA" added to store.
# CertUtil: -addstore command completed successfully.

# Check current CA validity
certutil -getreg ca\ValidityPeriod
certutil -getreg ca\ValidityPeriodUnits
#... 2 years

# Set to 5 years (adjust as needed)
certutil -setreg ca\ValidityPeriod "Years"
certutil -setreg ca\ValidityPeriodUnits 5
#... 5 years

# Restart AD CS service
Restart-Service certsvc -Force

# Verify chain
certutil -verify "$template.cer" | Out-File "$template.cer.verify" 

# Check (builtin) template settings
certutil -template "SubCA" -v

# Add to this host's Trust Store
# On Domain Controller:
# 1. Copy CER file to NETLOGON share
Copy-Item "$template.cer" "\\$env:USERDNSDOMAIN\NETLOGON\"
# 2. Create GPO to deploy to all domain members:
gpupdate /force  # Wait for replication

# Verify 
# On any client, check if subordinate CA is trusted:
certutil -store "CA" | Select-String "LIME-ISSUING-CA"
# Test chain validation:
certutil -verify -urlfetch "$template.cer"

# Import into CA store
certutil -f -dspublish subCA.cer NTAuthCA  # For enterprise trust
gpupdate /force

# Publish CRLs
certutil -CRL
# Create a virtual directory in IIS (run as admin)
Import-Module WebAdministration
New-WebVirtualDirectory -Site "Published CRL List" -Name "cdp" -PhysicalPath "C:\Windows\System32\CertSrv\CertEnroll"

# Grant read access
icacls "C:\Windows\System32\CertSrv\CertEnroll" /grant "IIS_IUSRS:(RX)"

# CRL Endpoint
http://pki.lime.lan/cdp/LIME-ISSUING-CA.crl
```

List the generated files

```powershell
S:\DC01\IaC\adcs\subCA
> dir


    Directory: S:\DC01\IaC\adcs\subCA


Mode                LastWriteTime         Length Name
----                -------------         ------ ----
-a----        5/31/2025   3:18 PM           1858 certutil.template.SubCA.log
-a----        5/31/2025   3:17 PM           3580 subCA.base64.cer
-a----        5/31/2025   3:04 PM           2560 subCA.cer
-a----        5/31/2025   3:16 PM           2603 subCA.cer.verify
-a----        5/31/2025   3:03 PM            319 subCA.inf
-a----        5/31/2025   3:04 PM           2210 subCA.req
-a----        5/31/2025   3:04 PM           6162 subCA.rsp
```

Export

This PowerShell script export that CA certificate to a file:

```powershell
$caName     = "LIME-ISSUING-CA"
$filePath   = "ca-sub-dc1.lime.lan.cer"
$filePath   = "subCA.cer"
$cert       = Get-ADObject -LDAPFilter "(cn=$caName)" -SearchBase "CN=Certification Authorities,CN=Public Key Services,CN=Services,$((Get-ADRootDSE).configurationNamingContext)" -Properties "cACertificate"

[System.IO.File]::WriteAllBytes($filePath, $cert."cACertificate"[0])

```

__FAILing__

```powershell
# Make the prompt readable
function prompt {
    "$PWD`n> "
}

# Set working dir
net use S: "\\tsclient\S" /persistent:yes
set-location S:\DC01\IaC\adcs\limeSubordinateCA
#net use S: /delete

# Set params
$path = (Get-Location).Path
$template = "$path\limeSubordinateCA"

# Define INF content (ensure this runs BEFORE Out-File)
$infContent = @'
[Version]
Signature = "$Windows NT$"

[NewRequest]
Subject = "CN=LIME-ISSUING-CA, DC=LIME, DC=LAN"
Exportable = FALSE
KeyLength = 4096
KeySpec = 2
MachineKeySet = TRUE
ProviderName = "Microsoft Software Key Storage Provider"
RequestType = PKCS10
HashAlgorithm = SHA256
KeyUsage = "CERT_DIGITAL_SIGNATURE_KEY_USAGE, CERT_KEY_CERT_SIGN_KEY_USAGE, CERT_CRL_SIGN_KEY_USAGE"

[Extensions]
BasicConstraints = "critical,CA:true,pathlength:1"
'@
$infContent | Out-File "$template.inf" -Encoding ASCII

# Generate the CSR
certreq -new "$template.inf" "$template.req"

# Verify
certutil -dump "$template.req"

```

```powershell
[EnhancedKeyUsageExtension]
OID=1.3.6.1.5.5.7.3.2 ; Client Authentication
OID=1.3.6.1.5.5.7.3.1 ; Server Authentication (optional, but common for PKI)
OID=2.5.29.37.0       ; Any Purpose (sometimes used for flexibility)
```

#### 2. Issue the Certificate from Your Root CA

```powershell
# Show Root CA info
certutil -cainfo 

$rootCA     = 'lime-DC1-CA'
$path       = (Get-Location).Path
$template   = "$path\limeSubordinateCA"

# Submit the request to (local) Root CA
certreq -submit -config "localhost\$rootCA" "$template.req" "$template.cer"
# Or if you need to specify the template (use the "SubCA" template)
certreq -submit -config "localhost\$rootCA" -attrib "CertificateTemplate:$template" "$template.req" "$template.cer"

# Install the issued certificate
certreq -accept $template.cer

```

#### 3. Install the Intermediate CA Role

```powershell
$path       = (Get-Location).Path
$template   = "$path\limeSubordinateCA"

# Install and configure the intermediate CA using the issued certificate
Install-AdcsCertificationAuthority `
    -CertFile $template.cer `
    -CAType EnterpriseSubordinateCA `
    -Force

```

### Post-Installation Configuration (Critical!)

#### 1. ~~Configure CRL and AIA Paths~~ 

__Don't bother.__ This is a hellscape of Microsoft tedium that soaks manhours and does nothing.

```powershell
$fqdn = 'dc1.lime.lan'

# Set CRL distribution points
certutil -setreg CA\CRLPublicationURLs "1:C:\Windows\system32\CertSrv\CertEnroll\%%3%%8%%9.crl\n2:file://\\pki.contoso.com\PKI\%%3%%8%%9.crl"

# Set AIA locations
certutil -setreg CA\CACertPublicationURLs "1:C:\Windows\system32\CertSrv\CertEnroll\%%1_%%3%%4.crt\n2:file://\\pki.contoso.com\PKI\%%1_%%3%%4.crt"

# Restart the service
Restart-Service certsvc -Force

# Publish the first CRL
certutil -crl
```

#### 2. Configure Certificate Templates

```powershell
# List available templates
Get-CATemplate

# Add templates you want this intermediate CA to issue
Add-CATemplate -Name "WebServer" -Force
Add-CATemplate -Name "WorkstationAuthentication" -Force
```

#### 3. Verify the Installation

```powershell
# Check the CA is operational
certutil -config "CONTOSO-ISSUING-CA" -ping

# View issued certificates
certutil -viewstore -silent CA
```

### Important Notes for Air-Gapped Networks

1. **Certificate Distribution**:
   - Manually export the intermediate CA certificate and distribute to all clients
   ```powershell
   certutil -ca.cert limeSubordinateCA.cer
   ```

2. **CRL Distribution**:
   - Since you're air-gapped, use file shares or manual distribution for CRLs
   - Set appropriate validity periods (longer than normal)

3. **Backup Immediately**:
   ```powershell
   Backup-CARoleService -Path C:\CA_Backup -Password (Read-Host -AsSecureString) -All
   ```

This approach keeps everything on one server while maintaining the security benefits of a two-tier hierarchy. The entire process should take less than 30 minutes if you copy/paste these commands.

## Request a Web-Server Certificate 

### Summary

AD CS of default Windows Server 2019 accepts __only RSA type__ CSRs.

Success at obtaining a TLS certificate for web server usage 
from AD CS web form of its Certificate Server at `https://dc1.lime.lan/certsrv/`

It responds with two certificates (end-entity and full-chain cert), 
both __in PKCS#7 format__ (`.p7b`), 
and so must be converted to PEM for use in most servers.
Their odd format is useful only at Microsoft and other legacy 
or non-standard servers such as Apache Tomcat.

- `certnew.p7b`

```bash
# Convert certificate from PKCS#7 (.p7b) to PEM format
cn=kube.lime.lan
openssl pkcs7 -print_certs -in certnew.p7b -out $cn.crt

# Parse the certificate
openssl x509 -noout -subject -issuer -startdate -enddate -ext subjectAltName -in $cn.crt
```

### CSR

Generate it in a form acceptable to the web form of 
Windows Certificate Server (`https://dc1.lime.lan/certsrv/`).

```bash
domain=lime.lan
cn=kube.$domain
TLS_ST=MD
TLS_L=AAC
TLS_O='SWK LLC'
TLS_OU=ops
## Create the configuration file (CNF) : See man config
## See: man openssl-req : CONFIGURATION FILE FORMAT section
## https://www.openssl.org/docs/man1.0.2/man1/openssl-req.html
cat <<EOH |tee $cn.cnf
[ req ]
prompt              = no        # Disable interactive prompts.
default_bits        = 2048      # Key size for RSA keys. Ignored for Ed25519.
default_md          = sha256    # Hashing algorithm.
distinguished_name  = req_distinguished_name 
req_extensions      = v3_req    # Extensions to include in the request.
[ req_distinguished_name ] 
CN              = $cn                   # Common Name
C               = ${TLS_C:-US}          # Country
ST              = ${TLS_ST:-NY}         # State or Province
L               = ${TLS_L:-Gotham}      # Locality name
O               = ${TLS_O:-Penguin Inc} # Organization name
OU              = ${TLS_OU:-GitOps}     # Organizational Unit name
emailAddress    = admin@$domain
[ v3_req ]
subjectAltName      = @alt_names
keyUsage            = digitalSignature
extendedKeyUsage    = serverAuth
[ alt_names ]
DNS.1 = $cn
DNS.2 = *.$cn   # Wildcard. CA must allow, else declare each subdomain.
EOH

# RSA : This is the only acceptable type under AD CS (2019).
openssl req -new -noenc -config $cn.cnf -extensions v3_req -newkey rsa:2048 -keyout $cn.key -out $cn.csr 
# ED25519
openssl req -new -noenc -config $cn.cnf -extensions v3_req -newkey ed25519 -keyout $cn.key -out $cn.csr
# ECDSA (NIST P-256 curve)
openssl req -new -noenc -config $cn.cnf -extensions v3_req -newkey ec:<(openssl ecparam -name prime256v1 -genkey) -keyout $cn.key -out $cn.csr

```
