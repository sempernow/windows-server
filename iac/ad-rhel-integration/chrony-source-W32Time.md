# WinSrv DCs (`W32Time`) as time sources of Linux `chrony`

## Q:

Are Windows Server domain controllers not viable sources for  RHEL 8/9 `chrony` configuration?

## A:

Windows Server DCs are absolutely viable NTP sources for RHEL chrony—and in AD-integrated environments, they're often the *recommended* choice. A few considerations though:

**Why it works well:**
- DCs run W32Time and serve NTP on UDP 123 by default
- Keeps time synchronized with the same source your Kerberos tickets depend on, avoiding clock skew authentication failures
- Windows Server 2016+ significantly improved W32Time accuracy (sub-second when configured properly)

**Typical `chrony.conf` for AD integration:**
```
server dc1.example.com iburst
server dc2.example.com iburst
driftfile /var/lib/chrony/drift
makestep 1.0 3
rtcsync
```

**Caveats:**
- Pre-2016 DCs: W32Time was historically accurate only to ~1-2 seconds, which is fine for Kerberos (5-minute tolerance) but inadequate if you need precision timing
- PDC emulator hierarchy: In AD, the PDC emulator FSMO role holder is the authoritative time source—other DCs sync from it. If that DC has bad time, it propagates
- Some orgs prefer a hybrid approach: DCs sync to stratum-1/2 external sources, Linux clients sync to DCs

**If you're seeing issues**, the most common problems are:
1. Firewall blocking UDP 123
2. W32Time not configured to serve NTP to non-domain members (check `w32tm /query /configuration` on the DC)
3. NTP version mismatches (rare with modern systems)

Is there a specific problem you're running into, or is this more of an architecture planning question for your homelab IdM setup?

## Q:

There were issues replacing `pool` with `server` entries of domain controllers, 
but solved by two parameter settings:

@ __`/etc/chrony.conf`__

```ini
...
acquisitionport 123
maxdistance 16
...
```

## A:

Ah, those are the classic __W32Time__ interop fixes.

**`acquisitionport 123`** — Some firewalls and older NTP implementations expect source port 123 (traditional ntpd behavior). _Chrony defaults to a random high port, which can get dropped_.

**`maxdistance 16`** — This is the real culprit with W32Time. ___Windows DCs often advertise absurdly high root dispersion values___, sometimes reporting several seconds of dispersion even when time is actually fine. Chrony's default `maxdistance 3` sees that and rejects the source as unreliable. 

Bumping it to 16 tells chrony "trust it anyway."

You can see what the DC is advertising with:

```bash
chronyc sourcestats
chronyc ntpdata
```

The `Std Dev` and `Root dispersion` fields will likely show why chrony was unhappy before the change.

Worth noting for documentation purposes: this is a known quirk and even Red Hat's own AD integration guides mention `maxdistance 16` as a workaround for W32Time's inflated dispersion reporting. 
It's not that the time is actually bad; W32Time just reports its uncertainty &hellip; pessimistically.

Good troubleshooting—those two settings aren't immediately obvious from error messages.


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
