# DNS Intermittent failure 

## Symptom

Windows Server DNS is spotty at WSL, only recently.

```bash
Ubuntu (master %=) [20:17:28] [1] [#0] /s/DEV/devops/infra/windows-server/iac/network
☩ nslookup kube.lime.lan
Server:         10.255.255.254
Address:        10.255.255.254#53

** server can't find kube.lime.lan: NXDOMAIN
```
```bash
Ubuntu (master %=) [20:17:44] [1] [#0] /s/DEV/devops/infra/windows-server/iac/network
☩ nslookup kube.lime.lan 192.168.11.2
Server:         192.168.11.2
Address:        192.168.11.2#53

kube.lime.lan   canonical name = k8s1.lime.lan.
Name:   k8s1.lime.lan
Address: 192.168.11.11
```

## Fix

REF: [`network-set.ps1`](network-set.ps1)

This network script reveals that the intermittent DNS behavior is caused by a routing and packet forwarding conflict between the WSL network ($WslAlias), the Hyper-V NAT switch (`$NatAlias`), and Windows packet forwarding rules.
Because OpenVPN toggles or system reboots intermittently disable Windows packet forwarding, the routing path between the WSL subnet and your Windows Server DC/DNS virtual switch breaks. Furthermore, using a manual `Set-NetIPAddress` workaround on the WSL interface frequently clashes with WSL's dynamic IP assignment upon restarts.
Here is how to stabilize DNS resolution from WSL to your Windows Server Active Directory/DNS VM.

## 1. Lock the WSL DNS to your Windows Server VM IP
By default, WSL tries to query the host's default Windows resolver. You need to force WSL to bypass the host and query your Windows Server VM directly.

1. Inside WSL, open `/etc/wsl.conf`:  
   `sudo nano /etc/wsl.conf`
2. Disable WSL from rewriting your DNS configuration file:
    ```conf
    [network]
    generateResolvConf = false
    ```
3. Delete the dynamically generated symlink and create a static file:
    ```bash
    sudo rm -f /etc/resolv.conf
    sudo nano /etc/resolv.conf
    ```
4. Point it directly to your Windows Server DC IP address 
(replace `192.168.X.X` with your exact Windows Server static IP on the NAT subnet):
    ```conf
    nameserver 192.168.X.X
    search yourdomain.local
    ```
5. Run `wsl --shutdown` in PowerShell to apply.

## 2. Switch WSL to Mirrored Networking mode
Your PowerShell script shows complex manual subnet routing (`Set-NetIPAddress -InterfaceAlias "$WslAlias"`). 
You can completely eliminate this fragile routing and bridging step by telling WSL to inherit the host network stack natively.
Create or update your `%USERPROFILE%\.wslconfig` file in Windows with the following settings:

[wsl2]
networkingMode=mirrored
dnsTunneling=true


* Why this works: mirrored mode makes WSL use the exact network interfaces of the Windows host. WSL will see the Hyper-V NAT network directly, bypassing the need for manual cross-interface packet forwarding or dynamic IP translation hacks.

## 3. Permanently Enforce Packet Forwarding (Fix the VPN/Reboot Drop)
As your script comments note, “Packet forwarding does not persist : Altered on reboot and OpenVPN-TAP toggle/usage.” When OpenVPN resets the adapters, Windows drops the forwarding state, breaking the route from WSL to the Hyper-V NAT switch.
You must force Windows to keep forwarding enabled globally in the registry rather than relying solely on the transient Set-NetIPInterface -Forwarding Enabled command.

   1. Open PowerShell as Administrator.
   2. Run this command to enable global IP routing permanently at the system level:
   
   Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name "IPEnableRouter" -Value 1
   
   3. Open the Windows Services manager (services.msc).
   4. Locate the Routing and Remote Access service.
   5. Change its Startup Type to Automatic and start the service. This guarantees that Windows actively routes packets between the WSL subnet and the Hyper-V NAT subnet even when OpenVPN tears down and rebuilds network adapters.

## 4. Check Windows Firewall for the WSL Subnet
Because your script programmatically forces the network categories to Private, ensure your Windows Server VM firewall allows incoming DNS queries (Port 53 UDP/TCP) from outside its immediate local subnet, as WSL queries will originate from the WSL CIDR block.
If you'd like, let me know:


---

<!-- 

… ⋮ ︙ • ● – — ™ ® © ± ° ¹ ² ³ ¼ ½ ¾ ÷ × ₽ € ¥ £ ¢ ¤ ♻ ⚐ ⚑ ✪ ❤  \ufe0f
☢ ☣ ☠ ¦ ¶ § † ‡ ß µ Ø ƒ Δ ☡ ☈ ☧ ☩ ✚ ☨ ☦ ☓ ♰ ♱ ✖  ☘  웃 𝐀𝐏𝐏 🡸 🡺 ➔
ℹ️ ⚠️ ✅ ⌛ 🚀 🚧 🛠️ 🔧 🔍 🧪 👈 ⚡ ❌ 💡 🔒 📊 📈 🧩 📦 🥇 ✨️ 🔚

# Markdown Cheatsheet

[Markdown Cheatsheet](https://github.com/adam-p/markdown-here/wiki/Markdown-Cheatsheet "Wiki @ GitHub")

# README HyperLink

README ([MD](__PATH__/README.md)|[HTML](__PATH__/README.html)) 

# Bookmark

- Target
<a name="foo"></a>

- Reference
[Foo](#foo)

-->
