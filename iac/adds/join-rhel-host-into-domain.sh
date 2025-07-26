#!/usr/bin/env bash
# Run as root at the target host

[[ "$(id -u)" == '0' ]] || exit 1

all='
    realmd 
    sssd 
    sssd-tools 
    samba-common 
    samba-common-tools 
    krb5-workstation 
    oddjob 
    oddjob-mkhomedir
    authselect
'
dnf install -y $all

systemctl enable --now firewalld.service

# Add services / Open ports 
systemctl is-active firewalld &&
    firewall-cmd --add-service={kerberos,dns,ldap,ldaps,samba} --permanent &&
        firewall-cmd --reload

# Join this host into domain of AD DC if not already
# (If not yet in AD DS, then prompts for password of the AD administrator.)
adm=Administrator
dc=dc1.$(hostname -d)
realm list |grep $(hostname -d) || realm join --user=$adm $dc || {
    e=$?
    echo ERR $e : Failed to authenticate against AD
    exit $e
}

systemctl enable --now sssd oddjobd
realm permit --all

# Set AD users' HOME to /home/$USER and allow for `ssh <USER>@<HOST>`
conf=/etc/sssd/sssd.conf
while [[ ! -f $conf ]]; do
    echo "Waiting for sssd.conf to be created..."
    sleep 1
done

[[ -f $conf ]] &&
    sed -i -e 's,/home/%u@%d,/home/%u,' \
        -e 's,/home/%u@%d,/home/%u,' \
        -e '/use_fully_qualified_names/d' $conf && 
            echo 'use_fully_qualified_names = False' |tee -a $conf

authselect current |grep sssd &&
    authselect current |grep with-mkhomedir || {
        authselect select sssd with-mkhomedir --backup pre-join-config &&
            authselect check || exit 33
     } 

systemctl daemon-reload
systemctl restart sssd oddjobd
