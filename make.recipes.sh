#!/usr/bin/env bash
#################################################################
# See recipes of Makefile
#################################################################
[[ -d $PRJ_ROOT ]] || {
    echo "❌️  ERR : Environment is UNCONFIGURED" >&2
    
    exit 1
}

rootCA(){
    len=4096
    days=3650
    ca_ext=v3_ca
    cn=${DC_TLS_CN:-Penguin Root CA}
    o=${DC_TLS_O:-Penguin Inc}
    ou=${DC_TLS_OU:-gotham.gov}
    c=${DC_TLS_C:-US}

    dir=${DC_TLS_DIR_ROOT_CA}
    [[ -d $dir ]] || {
        echo "❌️  ERR : Path does NOT EXIST : '$dir'" >&2
        return 11
    }
    rm -rf $dir/*.*
    path="$dir/${cn// /-}"
    
    echo "🛠️  Create all PKI of the Root CA" >&2

	tee $path.cnf <<-EOH
	# Generated @ ${BASH_SOURCE##*/}
	[ req ]
	prompt              = no
	default_bits        = $len
	default_md          = sha256
	distinguished_name  = req_distinguished_name
	x509_extensions = $ca_ext
	[ req_distinguished_name ]
	CN  = $cn
	O   = $o
	OU  = $ou
	C   = $c
	[ $ca_ext ]
	basicConstraints        = critical, CA:TRUE # Append pathlen:1 to limit chain to one subordinate CA
	keyUsage                = critical, digitalSignature, keyCertSign, cRLSign
	subjectKeyIdentifier    = hash
	EOH

    ## Generate key and CSR  : -noenc else -aes256 to encrypt w/ AES-256 (password)
    openssl req -new -config $path.cnf -noenc -newkey rsa:$len -keyout $path.key -out $path.csr
    ## Sign the root cert with root key, applying the extensions of CSR
    openssl x509 -req -in $path.csr -extensions $ca_ext -extfile $path.cnf -signkey $path.key \
        -days $days -sha384 -out $path.crt
    
    # ## Generate both key and cert from CNF in one statement; skip the CSR
    # openssl req -x509 -new -nodes -keyout $path.key -days $days -config $path.cnf -extensions v3_ca 
    #     -out $path.crt

    echo "🔍  Parse the certificate located at '$path.crt'" >&2 # man x509v3_config
    # The extension (x509v3) of most interest in leaf certs is subjectAltName (SAN); other ext's are mostly inspected of CA certs.
    x509v3='subjectAltName,issuerAltName,basicConstraints,keyUsage,extendedKeyUsage,authorityInfoAccess,subjectKeyIdentifier,authorityKeyIdentifier,crlDistributionPoints,issuingDistributionPoints,policyConstraints,nameConstraints'
    openssl x509 -noout -subject -issuer -startdate -enddate -ext "$x509v3" -in $path.crt \
        |tee $path.crt.parse

}
crl(){
    ## Get CRL from https://dc1.lime.lan/certsrv/certcarc.asp
    openssl crl -inform PEM -text -noout -in $1
    ## See output : 
        # Revoked Certificates:
        # Serial Number: 1F000000064F9FE093DA77F9A9000000000006
    ## Get serial number of a certificate:
        # openssl x509 -noout -serial -in $crt
}

"$@" || echo "❌️  ERR : $?" >&2
