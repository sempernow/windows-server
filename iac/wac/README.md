# Windows Admin Center (WAC)

>Web UI for _remote management_ of Windows Server 2019/2022/2025

## Install 

Installing via non-interactive PowerShell script is one of the most common and cleanest ways to deploy Windows Admin Center on Server 2019 (especially Server Core).

- [`wac-install.ps1`](wac-install.ps1)
- [`wac-install-pro.ps1`](wac-install-pro.ps1)

### How to use it

1. Copy the script onto the target WS 2019 machine.
2. Open an elevated __PowerShell__ prompt (__Run as Administrator__).
3. If execution policy blocks it (very common), run once:

   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```

4. Run the script:

   ```powershell
   .\wac-install.ps1
   ```

Script `wsl-install-pro` will download the latest MSI, install silently on port 443 with a self-signed cert, create a detailed log, open the firewall port, and tell you the URL.

You can also easily modify the variables at the top if you want a different port, an existing certificate, or to install as a gateway on a workstation instead of a server.

---

## IIS interferes with WAC


Having installed it onto WS 2019 host at `dc1.lime.lan`, browsing to `https://dc1.lime.lan` takes us to a landing page  for IIS, not WAC.

### Diagnosis
The issue you're describing—accessing `https://dc1.lime.lan` and landing on the IIS default page ("Welcome to Windows Server" or similar stylized content with no WAC interface)—is a classic port binding conflict on Windows Server 2019. Here's why:

- **WAC Installation Behavior**: When you installed WAC with `SME_PORT=443`, it registers an HTTP.SYS URL reservation for `https://+:443/` (all hostnames on port 443) and binds an SSL certificate to `0.0.0.0:443`. This is handled by the Windows HTTP Server API (http.sys, PID 4/"System" process), **not** through IIS. WAC runs as its own service (`SmRdService` or similar) and doesn't create an IIS site.
  
- **IIS Interference**: If IIS (Web Server role) is installed and enabled—with its Default Web Site bound to HTTPS on port 443 (common default)—IIS competes for the same binding. Since both use http.sys under the hood, the first to fully claim the port wins. In your case, IIS is intercepting requests to `dc1.lime.lan:443` and serving its default content, blocking WAC.

- **Why the FQDN Matters**: WAC's URL reservation is wildcard (`+`), so it should handle any hostname like `dc1.lime.lan`. But if IIS has a tighter binding (e.g., specific IP or hostname) or started first, it takes precedence. No port specified in the URL defaults to 443.

This is a well-documented conflict, especially on servers with IIS roles (e.g., for Exchange, SharePoint, or custom sites).

### Quick Verification Steps
Run these in an elevated PowerShell on `dc1.lime.lan` to confirm:

1. **Check what's listening on 443**:
   ```powershell
   netstat -ano | findstr :443
   ```
   - Look for `TCP 0.0.0.0:443` or `[::]:443` owned by PID 4 (System/http.sys). Multiple lines may indicate overlap.

2. **Inspect HTTP.SYS reservations** (shows WAC's claim):
   ```powershell
   netsh http show urlacl | findstr 443
   netsh http show sslcert | findstr 443
   ```
   - Expect `https://+:443/` (URL ACL) and a cert thumbprint bound to `0.0.0.0:443` (SSL cert).

3. **Check IIS bindings**:
   - Open IIS Manager (`inetmgr`), expand Sites > Default Web Site > Bindings.
   - If HTTPS:443 is listed (with any IP/*), that's the conflict.

4. **Review WAC logs** (from your install: `C:\WindowsAdminCenter-install.log` or `%programdata%\Microsoft\ServerManagement\logs`):
   - Look for binding errors like "port already in use."

### Resolution Options
Choose based on your needs (e.g., do you require IIS on 443? For production, avoid 443 if possible to prevent future conflicts).

#### Option 1: Reinstall WAC on a Non-Standard Port (Recommended for Simplicity)
This keeps IIS on 443 untouched. Use the script from before, but change `$Port = 6516` (WAC default).

1. Uninstall WAC:
   ```powershell
   msiexec /x WindowsAdminCenter.msi /qn
   ```
   - Or via Settings > Apps > Windows Admin Center > Uninstall.

2. Clean up bindings (run as admin):
   ```powershell
   netsh http delete sslcert ipport=0.0.0.0:443
   netsh http delete urlacl url=https://+:443/
   ```
   - Restart the server or run `iisreset` if IIS is affected.

3. Re-run your `wac-install.ps1` with `$Port = 6516` (edit the script).
   - Access WAC at `https://dc1.lime.lan:6516`.

#### Option 2: Configure IIS to Not Use 443 (If You Don't Need IIS on Default Port)
1. Open IIS Manager.
2. Sites > Default Web Site > Bindings > Edit the HTTPS binding > Change port to 8443 (or remove it entirely).
3. Restart IIS: `iisreset`.
4. Test `https://dc1.lime.lan`—should now load WAC's login page (blue interface, no "IIS" text).
   - If still stuck, run the cleanup commands from Option 1, then reinstall WAC.

#### Option 3: Host Both on 443 Using Host Headers (Advanced, for Co-Existence)
If you must share 443 (e.g., IIS for other sites):
- Bind IIS to a specific hostname (e.g., `web.lime.lan:443`) via host headers.
- Reconfigure WAC to a specific hostname:
  1. Rerun the WAC installer interactively (download MSI, run as admin).
  2. Choose "Custom configuration" > Set FQDN to `dc1.lime.lan` > Port 443.
  - This creates a tighter URL reservation like `https://dc1.lime.lan:443/`.
- Ensure DNS points correctly. Access WAC at `https://dc1.lime.lan` and IIS at `https://web.lime.lan`.
- Drawback: Requires certs valid for both hostnames.

#### Option 4: Stop/Disable IIS Default Site (Quick Test)
- In IIS Manager: Sites > Default Web Site > Stop (or Manage Website > Stop).
- Test `https://dc1.lime.lan`—if WAC loads, confirm the conflict. Restart site after testing.

### Post-Fix Steps
- **Firewall**: Ensure TCP 443 (or your new port) is open inbound.
- **Cert Trust**: If using self-signed (`generate`), add it to your browser's trusted roots or use a CA cert.
- **Access Local Server**: Once at WAC's login, sign in with domain admin creds. The "All connections" page should auto-discover `dc1.lime.lan` (local host). If not, add it manually via IP/FQDN.
  - For local management: No extra config needed, but ensure WinRM is enabled: `Enable-PSRemoting -Force`.
- **If Still No Local Server Menu**: In WAC > Settings > Gateway > Update the local server entry with `dc1.lime.lan`. Check TrustedHosts if connecting from another machine: `Set-Item WSMan:localhost\Client\TrustedHosts -Value 'dc1.lime.lan'`.


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
