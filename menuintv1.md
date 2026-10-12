Here is the cleanly formatted, production-ready GitHub Markdown file (.md) based on your blueprint. It uses standard GitHub-Flavored Markdown (GFM) with clear visual hierarchy, descriptive code block tags, and atomic steps optimized for documentation layout.

# Simple Menu Item Addition in Services Tab (OpenWrt v25.x)
This document provides the final blueprint for establishing a parallel test environment for Tailscale on OpenWrt v25.x. Every file, path, and command is completely self-contained below.
### 📋 Environment Profile*   **Target OS:** OpenWrt v25.x (Modern LuCI client-side rendering framework)*   **Hardware:** Raspberry Pi Zero 2 W (All dependencies/package requirements are met)
*   **Access Method:** Windows PowerShell (SSH) and `nano` text editor
---## 🛠️ Step-by-Step Implementation### Step 1: Create the Backend Script*   **File Location:** `/usr/libexec/rpcd/tailscale_test` *(No `.sh` extension, no hyphens)*
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
                    /usr/sbin/tailscale up --accept-dns=false --exit-node=IP_Address --exit-node-allow-lan-access=true 2>/dev/null
                fi
                echo '{"result":true}'
                ;;
        esac
        ;;
esac
```
---### Step 2: Create the Security Access Rule (ACL)*   **File Location:** `/usr/share/rpcd/acl.d/tailscale_test.json`
```json
{
	"luci-app-tailscale-test": {
		"description": "Grant access to custom Tailscale test actions",
		"read": {
			"ubus": {
				"tailscale_test": [ "status" ]
			}
		},
		"write": {
			"ubus": {
				"tailscale_test": [ "toggle" ]
			}
		}
	}
}
```
---### Step 3: Create the Menu Registration*   **File Location:** `/usr/share/luci/menu.d/luci-app-tailscale-test.json`
```json
{
	"admin/services/tailscale-test": {
		"title": "Tailscale Test Mode",
		"action": {
			"type": "view",
			"path": "tailscale/toggle_test"
		},
		"order": 65,
		"depends": {
			"acl": [ "luci-app-tailscale-test" ]
		}
	}
}
```
---### Step 4: Create the Frontend User Interface*   **File Location:** `/www/luci-static/resources/view/tailscale/toggle_test.js`
```javascript
'use strict';

const callTailscaleStatus = L.rpc.declare({
	object: 'tailscale_test',
	method: 'status',
	expect: { result: 'Stopped' }
});

const callTailscaleToggle = L.rpc.declare({
	object: 'tailscale_test',
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
			E('h2', {}, _('Tailscale VPN (TEST)')),
			E('div', { 'class': 'cbi-map-descr' }, _('Testing execution flow for OpenWrt v25 native modern framework.')),
			E('div', { 'class': 'cbi-section' }, [
				E('div', { 'class': 'cbi-section-node' }, [
					E('div', { 'class': 'cbi-value' }, [
						E('label', { 'class': 'cbi-value-title' }, _('Current Test State')),
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
										E('p', { 'class': 'spinning' }, _('Firing parallel execution toggle...'))
									]);
									return callTailscaleToggle().then(function() {
										window.location.reload();
									});
								}, this)
							}, isRunning ? _('Stop Test Context') : _('Start Test Context'))
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
---### Step 5: Run the Execution ChecklistPaste these exact commands into your terminal to apply permissions, clean hidden Windows characters (in case they snuck in via PowerShell), and reset the LuCI cache:
```bash
# 1. Enforce executable rights
chmod +x /usr/libexec/rpcd/tailscale_test

# 2. Automatically clean any Windows CRLF formatting issues
sed -i 's\(/\r\)\$//' /usr/libexec/rpcd/tailscale_test
sed -i 's\(/\r\)\$//' /usr/share/rpcd/acl.d/tailscale_test.json
sed -i 's\(/\r\)\$//' /usr/share/luci/menu.d/luci-app-tailscale-test.json
sed -i 's\(/\r\)\$//' /www/luci-static/resources/view/tailscale/toggle_test.js

# 3. Reload services and flush memory cache
/etc/init.d/rpcd restart
rm -rf /tmp/luci-indexcache* /tmp/luci-modulecache/*
```
---### Step 6: Log out and Log back in> [!IMPORTANT]> Because security profile changes require an active session update, you must log out of the router web interface completely, then log back in.

Once authenticated again, navigate to **Services -> Tailscale Test Mode** to view and test your interface.

Would you like me to make any adjustments, such as adding a troubleshooting section, adding an entry for creating a LuCI development environment setup guide, or altering the JSON configurations? Let me know how you'd like to expand this documentation.

