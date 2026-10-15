# LuCI Sidebar Menu Integration (OpenWrt v25.x Modern Framework)

This document provides the production blueprint for migrating from legacy custom button shortcuts to a fully native, client-side rendered UI panel inside the OpenWrt v25.x web interface. 

By utilizing OpenWrt's modern **RPCD (Routing Policy Control Daemon)** and JavaScript component engine, we register a sleek, dynamic status-and-toggle controller under the **Services** tab without relying on bloated external application hooks.

### 📋 Architectural Profile
*   **Target Subsystem:** LuCI client-side JavaScript rendering (OpenWrt v25.x compatibility matrix)
*   **Security Context:** Explicit RPC user/group permission enforcement (`ubus` access validation)
*   **Footprint Reduction:** Removes the need for `luci-app-commands` entirely, freeing up critical memory on the Pi Zero 2 W's 512MB RAM stack.

---

## 🛠️ Step-by-Step Implementation
## Note: this working but needs editing to be precise like some folders need creation if not existing and the tailscale node needs bringing up to register it

### Step 1: Deploy the Production Backend Script
This script handles the raw system commands. It monitors your Tailscale background process via `pgrep`, checks status vectors via Tailscale's JSON engine, and safely triggers up/down routing changes.

*   **File Location:** `/usr/libexec/rpcd/tailscale`  
*   *Note: Do not append a `.sh` file extension, and do not use hyphens in the filename.*

```sh
#!/bin/sh

case "$1" in
    list)
        echo '{ "status": {}, "toggle": {} }'
        ;;
    call)
        case "$2" in
            status)
                if pgrep tailscaled > /dev/null; then
                    STATE=$(/usr/sbin/tailscale status --json 2>/dev/null | grep -o '"BackendState":"[^"]*"' | cut -d'"' -f4)
                    echo "{\"result\":\"${STATE:-Running}\"}"
                else
                    echo '{"result":"Stopped"}'
                fi
                ;;
            toggle)
                if pgrep tailscaled > /dev/null; then
                    /usr/sbin/tailscale down 2>/dev/null
                    /etc/init.d/tailscale stop >/dev/null 2>&1
                else
                    /etc/init.d/tailscale start >/dev/null 2>&1
                    sleep 3
                    /usr/sbin/tailscale up --accept-dns=false --exit-node=YOUR-HOME-EXIT-NODE-IP --exit-node-allow-lan-access=true 2>/dev/null
                fi
                echo '{"result":true}'
                ;;
        esac
        ;;
esac
```

---

### Step 2: Inject the Security Access Control Rule (ACL)
Modern OpenWrt versions require absolute security sandboxing. This JSON dictionary profile strictly explicitly explicitly allows the web framework's UI engine to run your custom backend actions.

*   **File Location:** `/usr/share/rpcd/acl.d/tailscale.json`

```json
{
	"luci-app-tailscale": {
		"description": "Grant access to custom Tailscale production actions",
		"read": {
			"ubus": {
				"tailscale": [ "status" ]
			}
		},
		"write": {
			"ubus": {
				"tailscale": [ "toggle" ]
			}
		}
	}
}
```

---

### Step 3: Register the Sidebar Menu Node
This maps your file right into the navigation tree underneath the primary Services dropdown list.

*   **File Location:** `/usr/share/luci/menu.d/luci-app-tailscale.json`

```json
{
	"admin/services/tailscale": {
		"title": "Tailscale VPN",
		"action": {
			"type": "view",
			"path": "tailscale/toggle"
		},
		"order": 65,
		"depends": {
			"acl": [ "luci-app-tailscale" ]
		}
	}
}
```

---

### Step 4: Create the Modern Frontend User Interface
This file utilizes OpenWrt's native client-side framework library (`L.rpc` and `E()`) to render your status badge, dynamically color-code connection states, and update your toggle button in real-time.

*   **File Location:** `/www/luci-static/resources/view/tailscale/toggle.js`

```javascript
'use strict';

const callTailscaleStatus = L.rpc.declare({
	object: 'tailscale',
	method: 'status',
	expect: { result: 'Stopped' }
});

const callTailscaleToggle = L.rpc.declare({
	object: 'tailscale',
	method: 'toggle',
	expect: { result: false }
});

return L.view.extend({
	load: function() {
		return callTailscaleStatus();
	},

	render: function(status) {
		let isRunning = (status === 'Running');
		let statusColor = isRunning ? 'green' : 'red';

		return E('div', { 'class': 'cbi-map' }, [
			E('h2', {}, _('Tailscale VPN')),
			E('div', { 'class': 'cbi-map-descr' }, _('Manage Tailscale routing states natively within the OpenWrt client framework.')),
			E('div', { 'class': 'cbi-section' }, [
				E('div', { 'class': 'cbi-section-node' }, [
					E('div', { 'class': 'cbi-value' }, [
						E('label', { 'class': 'cbi-value-title' }, _('Current Connection State')),
						E('div', { 'class': 'cbi-value-field' }, [
							E('span', { 'style': 'font-weight:bold; color:' + statusColor }, status)
						])
					]),
					E('div', { 'class': 'cbi-value' }, [
						E('label', { 'class': 'cbi-value-title' }, _('Action Switch')),
						E('div', { 'class': 'cbi-value-field' }, [
							E('button', {
								'class': 'cbi-button cbi-button-action ' + (isRunning ? 'important' : 'save'),
								'click': L.bind(function(ev) {
									L.ui.showModal(null, [
										E('p', { 'class': 'spinning' }, _('Toggling Tailscale service context...'))
									]);
									return callTailscaleToggle().then(function() {
										window.location.reload();
									});
								}, this)
							}, isRunning ? _('Stop Tailscale') : _('Start Tailscale'))
						])
					])
				])
			])
		]);
	},

	handleSaveApply: null,
	handleSave: null,
	handleReset: null
});
```

---

### Step 5: Execution Checklist (Powershell SSH)
Paste these exact commands into your terminal to wipe any old test entries, enforce script executables, strip structural Windows carriage returns (`\r`), and rebuild the LuCI index cache:

```bash
# 1. Enforce script execution rights on the backend system binary
chmod +x /usr/libexec/rpcd/tailscale

# 2. Automatically clean hidden Windows CRLF line formatting issues 
sed -i 's\(/\r\)\$//' /usr/libexec/rpcd/tailscale
sed -i 's\(/\r\)\$//' /usr/share/rpcd/acl.d/tailscale.json
sed -i 's\(/\r\)\$//' /usr/share/luci/menu.d/luci-app-tailscale.json
sed -i 's\(/\r\)\$//' /www/luci-static/resources/view/tailscale/toggle.js

# 3. Bounce the RPC daemon and flush memory caching engines
/etc/init.d/rpcd restart
rm -rf /tmp/luci-indexcache* /tmp/luci-modulecache/*
```

---

### Step 6: Session Initialization
> [!IMPORTANT]
> Because ACL security configuration updates modify session tokens at runtime, you must log out of the router web page completely, then log back in.

Your fresh, production-ready control node is now fully integrated and accessible under **Services -> Tailscale VPN**.
