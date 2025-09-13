#!/usr/bin/env bash
#####################################################
# Update RHEL trust store with DC1 CA certificate
#####################################################
[[ "$(id -u)" -ne 0 ]] && {
    echo "️❌ ERR : MUST run as root" >&2

    exit 11
}

[[ -r $1 ]] || {
    echo "️❌ ERR : Certificate '$1' is not readable" >&2

    exit 22
}

cp $1 /etc/pki/ca-trust/source/anchors/
chown root:root /etc/pki/ca-trust/source/anchors/*
chmod 640 /etc/pki/ca-trust/source/anchors/*

update-ca-trust || {
    echo "️❌ ERR : update-ca-trust exited with '$?'" >&2

    exit 33
}

ref=$(hostname -d)
head /etc/ssl/certs/ca-bundle.crt |grep ${ref%.*} || {
    echo "️❌ ERR : CA reference '${ref%.*}' NOT found in ca-bundle.crt" >&2

    exit 44
}
