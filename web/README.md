# ALBU BANK ONLINE

This folder is the PHP website. The website does not store account balances. Minecraft remains the source of truth.

## XAMPP setup

1. Copy the `web` folder into your XAMPP `htdocs` directory, for example:

```text
C:\xampp\htdocs\albubank\web\
```

2. Open `web/config.php` and replace `CHANGE_THIS_ALBU_BANK_BRIDGE_SECRET` with a long random secret.

3. Start Apache in XAMPP.

4. From a computer connected to the same Radmin VPN, open:

```text
http://YOUR_RADMIN_IP/albubank/web/
```

Replace `YOUR_RADMIN_IP` with the Radmin VPN IPv4 address of the PC running XAMPP.

## Minecraft bridge setup

Copy `web_bridge.lua` to a computer in the ALBU BANK network. This can be the same computer as `bank_server.lua`.

Edit these two lines:

```lua
local API_URL = "http://YOUR_RADMIN_IP/albubank/web/bridge.php"
local BRIDGE_SECRET = "THE_SAME_SECRET_AS_CONFIG_PHP"
```

Then run:

```text
web_bridge
```

The bridge polls the PHP site, sends each request through the existing ALBU BANK modem protocol, and returns the bank server response to PHP.

## Current online features

- Account ID + PIN login.
- Live account balance from Minecraft.
- Transaction history from Minecraft.
- Account-to-account transfers.
- Bank-side validation of PIN, account status and available balance.
- No separate PHP balance database.

## Important network note

CC:Tweaked normally blocks requests to local/private IP addresses. For a Radmin VPN address, the Minecraft server's CC:Tweaked HTTP rules must allow the PHP host. On Minecraft 1.13+ with modern CC:Tweaked this is configured in `serverconfig/computercraft-server.toml`; remove or adjust the private-IP deny rule as appropriate. See the CC:Tweaked local-IP guide.

If the Minecraft server is on a hosting provider which cannot route to your Radmin VPN network, the direct Radmin setup will not work from that server. In that case the bridge endpoint must be reachable from the Minecraft host by another route.
