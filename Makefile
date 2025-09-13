##############################################################################
## Makefile.settings : Environment Variables for Makefile(s)
#include Makefile.settings
# … ⋮ ︙ • “” ‘’ – — ™ ® © ± ° ¹ ² ³ ¼ ½ ¾ ÷ × ₽ € ¥ £ ¢ ¤ ♻ ⚐ ⚑ ✪ ❤ \ufe0f
# ☢ ☣ ☠ ¦ ¶ § † ‡ ß µ Ø ƒ Δ ☡ ☈ ☧ ☩ ✚ ☨ ☦ ☓ ♰ ♱ ✖  ☘  웃 𝐀𝐏𝐏 🡸 🡺 ➔
# ℹ️ ⚠️ ✅ ⌛ 🚀 🚧 🛠️ 🔧 🔍 🧪 👈 ⚡ ❌ 💡 🔒 📊 📈 🧩 📦 🥇 ✨️ 🔚
##############################################################################
## Environment variable rules:
## - Any TRAILING whitespace KILLS its variable value and may break recipes.
## - ESCAPE only that required by the shell (bash).
## - Environment hierarchy:
##   - Makefile environment OVERRIDEs OS environment lest set using `?=`.
##  	 - `FOO ?= bar` is overridden by parent setting; `export FOO=new`.
##  	 - `FOO :=`bar` is NOT overridden by parent setting.
##   - Docker YAML `env_file:` OVERRIDEs OS and Makefile environments.
##   - Docker YAML `environment:` OVERRIDEs YAML `env_file:`.
##   - CMD-inline OVERRIDEs ALL REGARDLESS; `make recipeX FOO=new BAR=new2`.

##############################################################################
## $(INFO) : Usage : `$(INFO) 'What ever'` prints a stylized "@ What ever".
SHELL   := /bin/bash
YELLOW  := "\e[1;33m"
RESTORE := "\e[0m"
INFO    := @bash -c 'printf $(YELLOW);echo "@ $$1";printf $(RESTORE)' MESSAGE

##############################################################################
## Project Meta

export PRJ_ROOT := $(shell pwd)
export LOG_PRE  := make
export UTC      := $(shell date '+%Y-%m-%dT%H.%M.%Z')


##############################################################################
## Domain Controller (DC)

export DC_DOMAIN          ?= lime.lan
export DC_FQDN            ?= dc1.${DC_DOMAIN}
export DC_VERSION         ?= 0.0.3
export DC_TLS_DIR_ROOT_CA ?= ${PRJ_ROOT}/iac/adcs/ca/root/v${DC_VERSION}
export DC_TLS_DIR_SUB_CA  ?= ${PRJ_ROOT}/iac/adcs/ca/sub/v${DC_VERSION}
export DC_TLS_DIR_LEAF    ?= ${PRJ_ROOT}/iac/adcs/leaf/kube.${DC_DOMAIN}/v${DC_VERSION}
export DC_TLS_CN          ?= Lime LAN Root CA
export DC_TLS_O           ?= Lime LAN
export DC_TLS_OU          ?= ${DC_DOMAIN}
export DC_TLS_C           ?= US


##############################################################################
## ADMIN USER

## ansibash
## Requires public key of ADMIN_USER copied to ~/.ssh/authorized_keys at targets.
#export ADMIN_USER          ?= $(shell id -un)
export ADMIN_USER          ?= u2
export ADMIN_KEY           ?= ${HOME}/.ssh/vm_lime
export ADMIN_TARGET_LIST   ?= a0 a1 a2 a3
export ADMIN_SRC_DIR       ?= $(shell pwd)
export ADMIN_DST_DIR       ?= /s/DC01

export ANSIBASH_TARGET_LIST ?= ${ADMIN_TARGET_LIST}
export ANSIBASH_USER        ?= ${ADMIN_USER}


##############################################################################
## Recipes : Meta

menu :
	$(INFO) 'Windows Server 2019'
	@echo "env          : Print the make environment"
	@echo "mode         : Fix folder and file modes of this project"
	@echo "eol          : Fix line endings : Convert all CRLF to LF"
	@echo "html         : Process all markdown (MD) to HTML"
	@echo "commit       : Commit and push this source"
	@echo "============== "
	@echo "rootca       : Create, push, and verify Root CA cert is in trust store of RHEL hosts"
	@echo "  -make      : Create PKI for Lime LAN Root CA"
	@echo "  -push      : Add CA certificate to trust store of RHEL hosts"
	@echo "  -test      : Test CA by client HTTPS request to DC1"

env :
	$(INFO) 'Environment'
	@echo "PWD=${PRJ_ROOT}"
	@env |grep DC_
	@env |grep ADMIN_
	@env |grep ANSIBASH_

eol :
	find . -type f ! -path '*/.git/*' -exec dos2unix {} \+
mode :
	find . -type d ! -path './.git/*' -exec chmod 0755 "{}" \;
	find . -type f ! -path './.git/*' ! -iname '*.key' -exec chmod 0644 "{}" \;
	find . -type f -path './iac/adcs/ca/*' -exec chmod 0440 "{}" \;
	find . -type f -path './iac/adcs/leaf/*' -exec chmod 0440 "{}" \;
	find . -type f ! -path './.git/*' -iname '*.key' -exec chmod 0400 "{}" \;
#	find . -type f ! -path './.git/*' -iname '*.sh' -exec chmod 0755 "{}" \;
tree :
	tree -d |tee tree-d
html :
	find . -type f ! -path './.git/*' -name '*.md' -exec md2html.exe "{}" \;
commit push : html mode
	gc && git push && gl && gs

##############################################################################
## Recipes : Cluster

# Scan subnet (CIDR) for IP addresses in use (running machines).
# - Manually validate that HALB_VIP is set to an *unused* address (within subnet CIDR).
# - Note this does not guarantee that an available VIP will remain so.
# - Protecting a VIP requires network admin.
scan :
	sudo nmap -sn ${HALB_CIDR} \
	    |tee ${ADMIN_SRC_DIR}/logs/${LOG_PRE}.scan.nmap.${UTC}.log
#	sudo arp-scan --interface ${HALB_DEVICE} --localnet \
#	    |tee ${ADMIN_SRC_DIR}/logs/${LOG_PRE}.scan.arp-scan.${UTC}.log

# Smoke test this setup
status hello :
	@ansibash 'printf "%12s: %s\n" Host $$(hostname) \
	    && printf "%12s: %s\n" User $$(id -un) \
	    && printf "%12s: %s\n" Kernel $$(uname -r) \
	    && printf "%12s: %s\n" firewalld $$(systemctl is-active firewalld.service) \
	    && printf "%12s: %s\n" SELinux $$(getenforce) \
	    && printf "%12s: %s\n" containerd $$(systemctl is-active containerd) \
	    && printf "%12s: %s\n" kubelet $$(systemctl is-active kubelet) \
	'

rootca-make :
	bash make.recipes.sh rootCA
# The cert created at rootca-make is *not* used by -push or -test as the CA certificate
cadir := iac/adcs/ca/root/v0.0.1
capem := lime-DC1-CA-fullchain.pem
rootca-push :
	ansibash -u ${cadir}/${capem}
	ansibash -u iac/adcs/update-ca-trust.sh
	ansibash sudo bash update-ca-trust.sh ${capem}
rootca-test :
	ansibash 'curl -sfI https://${DC_FQDN} |grep HTTP || echo ERR $$?'