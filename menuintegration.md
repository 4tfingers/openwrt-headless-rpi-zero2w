# Using Custom rpcd Executable Plugins to Expose Backend Logic Over ubus

The custom approach works by having the `rpcd` daemon call the executable script:
* **List:** When running `list`, the script tells `ubus` what methods are available.
* **Call:** When running `call`, it passes data to the backend.
* **Description:** Check UPS Battery Status
---
### 📊 5. Optional: LuCI Visual Battery Dashboard Status Check
To view real-time battery voltage and estimated capacities directly from the LuCI web panel without terminal use:

1. Build an execution script at `/usr/bin/muy_ups_status.py` with executable permissions (`chmod +x`).

When triggered, it parses the binary register values and delivers a clean status window directly within the web dashboard.
Create a tiny executable asset at `/usr/bin/muy_ups_status.py`:

```bash
nano /usr/bin/muy_ups_status.py
```

```python
#!/usr/bin/env python3
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
```

Make the script executable:
```bash
chmod +x /usr/bin/muy_ups_status.py
```

## Step 1: Implementation Paths

Because the UPS script is written in Python, there are two clean paths to implement this.

### Option A: Use a Python Script Directly as the rpcd Executable
Instead of writing a shell wrapper, your file under `/usr/libexec/rpcd/` can be written purely in Python. `rpcd` treats anything executable as a plugin, meaning Python works perfectly as long as it handles the `list` and `call` arguments and responds in JSON.

1. Create your new plugin script (No `.py` extension, no hyphens):
   ```bash
   nano /usr/libexec/rpcd/upsstatus
   sed -i 's/\r$//' /usr/libexec/rpcd/upsstatus
   ```

2. Paste the Python implementation that matches the `rpcd` communication layout:
   ```python
   #!/usr/bin/env python3
   import sys
   import json
   import subprocess

   def get_ups_data():
       # This calls your actual script logic or executes terminal tasks safely
       try:
           # If your logic lives in another script file:
           res = subprocess.run(["python3", "/usr/bin/muy_ups_status.py"], capture_output=True, text=True)
           return res.stdout if res.returncode == 0 else res.stderr
       except Exception as e:
           return f"Error executing UPS script: {str(e)}"

   def main():
       if len(sys.argv) < 2:
           sys.exit(1)

       cmd = sys.argv[1]

       if cmd == "list":
           # Registers the method 'get_status' under ubus 'upsstatus'
           # It has no mandatory input arguments
           print(json.dumps({"get_status": {}}))

       elif cmd == "call":
           method = sys.argv[2] if len(sys.argv) > 2 else ""
           if method == "get_status":
               # rpcd expects a strict JSON object structure back
               output_text = get_ups_data()
               print(json.dumps({"status_output": output_text}))

   if __name__ == "__main__":
       main()
   ```

### Option B: Keep sh for rpcd and Call Python Internally
If you prefer to stick closer to your original `tailscale_test` shell architecture, you can keep the `rpcd` interface in a standard `sh` script and use it to execute the Python file.

1. Create your shell wrapper:
   ```bash
   nano /usr/libexec/rpcd/upsstatus
   ```

2. Paste the standard `sh` framework matching your previous setup, executing Python under the `call` case:
   ```sh
   #!/bin/sh

   case "$1" in
       list)
           # Define your ubus method name
           echo '{ "get_status": {} }'
       ;;
       call)
           case "$2" in
               get_status)
                   # Run the python script and format its string output safely into JSON
                   OUTPUT=$(python3 /usr/bin/muy_ups_status.py)

                   # Use jo or basic printf to safely escape the string inside JSON output
                   printf '{"status_output":%s}\n' "$(echo "$OUTPUT" | jq -R -s '.')"
               ;;
           esac
       ;;
   esac
   ```

---

## Final Steps to Register the Plugin

Whichever option you choose, configure permissions and reload the daemon to make your changes live.

1. **Make the file executable:**
   ```bash
   chmod +x /usr/libexec/rpcd/upsstatus
   sed -i 's/\r$//' /usr/libexec/rpcd/upsstatus
   ```

2. **Reload rpcd:**
   ```bash
   service rpcd restart
   ```

3. **Test via CLI:** Check if `ubus` sees your new backend hook:
   ```bash
   ubus list upsstatus
   ubus call upsstatus get_status
   ```

Once working via the CLI, you can pull the data directly into your clean JavaScript UI view using a standard `this.ubus('upsstatus', 'get_status')` call!

---

## Step 2: The Access Control List (ACL) Profile

Because modern LuCI relies on strict browser-to-router security, your frontend view will get a permission error unless you explicitly authorize access to your new Ubus service.

1. Run this command on your router:
   ```bash
   nano /usr/share/luci/menu.d/luci-app-ups.json
   sed -i 's/\r$//' /usr/share/luci/menu.d/luci-app-ups.json
   ```

2. If you haven't created the menu definition file yet, paste the following code. It groups both the menu location and its security permissions cleanly in one single modern JSON file:
   ```json
   {
   	"admin/services/ups": {
   		"title": "UPS Status",
   		"order": 60,
   		"action": {
   			"type": "view",
   			"path": "services/ups"
   		},
   		"depends": {
   			"acl": [ "luci-app-ups" ]
   		}
   	},
   	"luci-app-ups": {
   		"description": "Grant access to the custom UPS ubus service",
   		"read": {
   			"ubus": {
   				"upsstatus": [ "get_status" ]
   			}
   		}
   	}
   }
   ```

---

## Step 3: The JavaScript UI View File

Next, create the frontend JavaScript view that talks directly to your `upsstatus` Ubus namespace and renders the layout on the dashboard.

1. Run this command:
   ```bash
   mkdir -p /www/luci-static/resources/view/services
   nano /www/luci-static/resources/view/services/ups.js
   ```

2. Paste the following modern ES6 LuCI view script:
   ```javascript
   'use strict';
   import * as luci from 'org.openwrt.luci';
   import * as ubus from 'org.openwrt.ubus';

   return luci.view.extend({
   	// Fetches the data from Ubus before rendering the layout
   	load: function() {
   		return ubus.call('upsstatus', 'get_status', {});
   	},

   	render: function(data) {
   		// Extract output or fallback if empty/undefined
   		let output = (data && data.status_output) ? data.status_output : _('No status information returned from the UPS service.');

   		return E('div', { 'class': 'cbi-map' }, [
   			E('h2', {}, _('UPS System Status')),
   			E('div', { 'class': 'cbi-map-descr' }, _('Live metrics and diagnostics from your custom UPS python framework.')),
   			
   			// Formatted container acting like a terminal window
   			E('div', { 
   				'style': 'background:#1e1e1e; color:#00ff00; padding:15px; border-radius:4px; font-family:monospace; white-space:pre-wrap; margin-top:15px; font-size:13px; line-height:1.5;' 
   			}, [ output ]),

   			// Action interface block
   			E('div', { 'class': 'cbi-page-actions' }, [
   				E('button', {
   					'class': 'cbi-button cbi-button-apply',
   					'click': () => location.reload()
   				}, [ _('Refresh Status') ])
   			])
   		]);
   	},

   	// Hides standard form buttons since this is a read-only visual status page
   	handleSaveApply: null,
   	handleSave: null,
   	handleReset: null
   });
   ```

---

## Step 4: Clear Caches and Apply Everything

1. **Enforce executable rights and resolve formatting:**

2. **Reload core services:**  
   For OpenWRT to process the updated menu schemas and pick up the new JavaScript paths, reload the core services:
   ```bash
   # Force rpcd to read your new ubus/ACL setup
   service rpcd restart

   # Clear out any cached LuCI application indexes
   rm -rf /tmp/luci-indexcache /tmp/luci-modulecache
   ```

Now, refresh your browser tab, head over to **Services ➔ UPS Status**, and you will see your script output reading directly from Python via Ubus.
