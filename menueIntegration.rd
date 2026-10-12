here is the complete, final blueprint for the parallel test environment. Every file, path, and command is completely self-contained below. You do not need to scroll up or look at any previous responses.

Step 1: Create the Backend Script
File Location: /usr/libexec/rpcd/tailscale_test (No .sh extension, no hyphens)
File Content:
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
                    /usr/sbin/tailscale up --accept-dns=false --exit-node=100.111.96.59 --exit-node-allow-lan-access=true 2>/dev/null
                fi
                echo '{"result":true}'
                ;;
        esac
        ;;
esac



Step 2: Create the Security Access Rule (ACL)
File Location: /usr/share/rpcd/acl.d/tailscale_test.json
File Content:
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



Step 3: Create the Menu Registration
File Location: /usr/share/luci/menu.d/luci-app-tailscale-test.json
File Content:
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



Step 4: Create the Frontend User Interface
File Location: /www/luci-static/resources/view/tailscale/toggle_test.js
File Content:
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



Step 5: Run the Execution Checklist
Paste these exact commands into your terminal to apply permissions, clean hidden Windows characters (in case they snuck in), and reset the cache:
# 1. Enforce executable rights
chmod +x /usr/libexec/rpcd/tailscale_test

# 2. Automatically clean any Windows CRLF formatting issues
sed -i 's/\r$//' /usr/libexec/rpcd/tailscale_test
sed -i 's/\r$//' /usr/share/rpcd/acl.d/tailscale_test.json
sed -i 's/\r$//' /usr/share/luci/menu.d/luci-app-tailscale-test.json
sed -i 's/\r$//' /www/luci-static/resources/view/tailscale/toggle_test.js

# 3. Reload services and flush memory cache
/etc/init.d/rpcd restart
rm -rf /tmp/luci-indexcache* /tmp/luci-modulecache/*



Step 6: Log out and Log back in
Because security profile changes require a session update, log out of the router web page completely, then log back in.
Once you are logged back in, check the Tailscale Test Mode page under Services. Let me know if the Stopped/Running status pulls up smoothly or if the browser throws any other warnings.





Ups_status.py

#!/usr/bin/env python3

# /etc/ups_status.py
import smbus
import sys

I2C_BUS = 1
UPS_ADDRESS = 0x42
REG_BUS_VOLTAGE = 0x02

def get_pack_data():
    try:
        bus = smbus.SMBus(I2C_BUS)
        read_data = bus.read_i2c_block_data(UPS_ADDRESS, REG_BUS_VOLTAGE, 2)
        raw_val = (read_data[0] << 8) | read_data[1]
        voltage = (raw_val >> 3) * 0.004

        # Calculate percentage based on 6.0V (empty) to 8.4V (full) range
        percentage = ((voltage - 6.0) / (8.4 - 6.0)) * 100
        if percentage > 100: percentage = 100.0
        if percentage < 0: percentage = 0.0

        return voltage, percentage
    except Exception:
        return None, None

v, p = get_pack_data()

if v is not None:
    print("========================================")
    print(f"       WAVESHARE 18650 UPS STATUS      ")
    print("========================================")
    print(f" Pack Voltage : {v:.2f} V  (Approx {v/2:.2f}V per cell)")
    print(f" Charge Level : {p:.1f} %")
    print("----------------------------------------")
    if v <= 6.4:
        print(" STATUS       : CRITICAL! Charge immediately.")
    elif v <= 7.2:
        print(" STATUS       : Low Battery")
    else:
        print(" STATUS       : Healthy / Operational")
    print("========================================")
else:
    print("Error: Could not communicate with UPS via I2C bus.")
    sys.exit(1)
