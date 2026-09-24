# 🎒 OpenWrt Headless Travel Router Blueprint

> 🚨 **[EMERGENCY TROUBLESHOOTING CHECKLIST](CHECKLIST.md)** 🚨
>
> A production-grade manual for deploying a resilient, headless Pi Zero 2 W travel router on the road without an initial internet uplink.
>

# Technical Documentation: Headless Provisioning of Raspberry Pi Zero 2 W (Dual Wi-Fi Setup via Windows Architecture)
> A foolproof method for headless OpenWrt setup using a Windows machine and DiskInternals Linux Writer

---

## 🔌 Hardware Requirements

| Component | Purpose | Notes |
| :--- | :--- | :--- |
| **Raspberry Pi Zero 2 W** | The core router hardware. | Low-power, ultra-portable computer running OpenWrt. |
| **MicroSD Card (8GB+)** | Storage for the OS and packages. | High-quality card (Class 10/U1) recommended for reliability. |
| **USB Wi-Fi Adaptor** | Secondary network interface. | Required to handle the WAN internet connection while the Pi's built-in Wi-Fi hosts the local AP.  I used a EDUP 3000Mbps WiFi 6E Wireless Network Card USB|
| **OTG Micro-USB Cable/Hub** | Connectivity. | Converts the Pi's Micro-USB port to standard USB-A for your network card. |
| **Reliable Power Supply** | Power source. | 5V 2.5A Micro-USB adapter or a stable power bank for travel use. |

---

### 📦 Modular Package Deployment Matrix

| Project Phase | Deployment Method | Required Packages | Purpose / Functionality |
| :--- | :--- | :--- | :--- |
| **🟢 Core Baseline** *(Vanilla Image)* | **Pre-compiled** via Firmware Selector | `kmod-mt7921u`, `kmod-mt7921-firmware`, `nano`, `luci-app-ttyd`, `luci-app-advanced-reboot`, `iwinfo`, `base-files` | Handles first-boot auto-shutdown, restores offline AP wireless matrix, provides web console (`ttyd`), dual-boot recovery, and safe terminal editing out of the box. |
| **🔵 Secure Tunnel** *(Optional Expansion)* | **On-Demand** via LuCI Software / CLI | `tailscale`, `kmod-tun`, `iptables-nft`, `luci-app-commands` | Establishes on-demand VPN routing through a home exit node via single-click dashboard buttons. |
| **🟡 Battery Protection** *(Optional Protection)* | **On-Demand** via LuCI Software / CLI | `kmod-i2c-bcm2835`, `i2c-tools`, `python3-light`, `python3-smbus` | Communicates with the hardware `INA219` battery chip over the I2C serial bus for automated graceful shutdowns. |

---

### 📋 Overview & Challenge
Provisioning a headless **Raspberry Pi Zero 2 W** with **OpenWrt** presents a classic "chicken-and-egg" dilemma: the device has no Ethernet port, and OpenWrt boots with Wi-Fi disabled by default. If the power plug is pulled aggressively during the initial boot sequence to access the storage media, the `ext4` root filesystem faces a severe risk of data corruption. 

This document outlines a foolproof, offline methodology to safely complete the initial system initialization, execute a pristine hardware halt, and configure a dual-radio matrix (**Onboard Wi-Fi as Access Point, External USB Wi-Fi as Station/Client**) using a standard Windows host machine.

### 🛠️ Prerequisites & Tools
*   **Target Device:** Raspberry Pi Zero 2 W with an external USB Wi-Fi adapter.
*   **Host Machine:** Windows System (Tested and confirmed stable on ARM-based **Surface Pro X**).
*   **Software Utilities:**
    *   **OpenWrt Firmware Selector** (Attended Sysupgrade Online Web Builder).
    *   **DiskInternals Linux Writer** (Essential utility for accessing and writing to Linux filesystems on Windows).
    *   A clean text editor (e.g., Notepad++ or VS Code).

---
### 💿 The Vanilla Base Image Recipe

To ensure completely offline, headless operations right from the very first boot, the baseline OpenWrt image is custom-compiled using the **OpenWrt Firmware Selector** (Attended Sysupgrade). This bakes the MediaTek Wi-Fi 6 USB drivers, native web-integrated consoles, partition recovery blocks, and system defaults directly into the initial flash payload.

When building your custom image, copy and paste this exact string directly into the **"Installed Packages"** array box:

```text
base-files bcm27xx-gpu-fw bcm27xx-utils ca-bundle dnsmasq dropbear e2fsprogs firewall4 fstools kmod-fs-vfat kmod-nft-offload kmod-nls-cp437 kmod-nls-iso8859-1 kmod-sound-arm-bcm2835 kmod-sound-core kmod-usb-hid libc libgcc libustream-mbedtls logd mkf2fs mtd netifd nftables odhcp6c odhcpd-ipv6only opkg partx-utils ppp ppp-mod-pppoe procd-ujail uci uclient-fetch urandom-seed cypress-firmware-43430-sdio brcmfmac-nvram-43430-sdio cypress-firmware-43455-sdio brcmfmac-nvram-43455-sdio kmod-brcmfmac wpad-basic-mbedtls kmod-i2c-bcm2835 kmod-spi-bcm2835 kmod-spi-bcm2835-aux iwinfo luci luci-app-attendedsysupgrade kmod-mt7921-firmware kmod-mt7921u luci-app-ttyd luci-app-advanced-reboot nano
```

*Note: `nano` has been appended to the end of the original package string to guarantee a friendly text editor is baked straight into the firmware compile, entirely avoiding the need for interactive shell editors down the line.*

### 🕹️ Step 1: The First-Boot "Clean Shutdown" Logic
The foundational breakthrough of this method relies on forcing the operating system to autonomously perform a clean power execution *only after* it completes its structural first-boot configuration (partition expansion, populating configuration templates, and creating SSH key pairs).

1. Open the [OpenWrt Firmware Selector](https://openwrt.org).
2. Select your exact profile (e.g., `Raspberry Pi Zero 2 W`).
3. Expand the **Customize Application and Script** section.
4. Add the appropriate driver packages for your external USB Wi-Fi card to the **Installed Packages** array (e.g., `kmod-mt7601u`, `mt7601u-firmware`, `wireless-regdb`, `iwinfo`).
5. Paste the following bootstrap script into the **Script to run on first boot (uci-defaults)** block:

```bash
#!/bin/sh
(
    # Take control of the onboard green activity LED and pulse a heartbeat
    if [ -e /sys/class/leds/led0/trigger ]; then
        echo "heartbeat" > /sys/class/leds/led0/trigger
    fi

    # Hold execution for 5 minutes (300 seconds) to ensure internal operations settle
    sleep 300

    # Extinguish LED right before dropping power
    if [ -e /sys/class/leds/led0/trigger ]; then
        echo "none" > /sys/class/leds/led0/trigger
        echo "0" > /sys/class/leds/led0/brightness
    fi

    # Trigger pristine unmount and power cut
    poweroff
) &
exit 0
```
6. Generate and download the custom image, then flash it to your MicroSD card.

---

### ⏱️ Step 2: Execution & Visual Verification
1. Insert the card into the Pi Zero 2 W and supply power.
2. **Visual Observation:** The green ACT LED will flicker erratically for roughly a minute as it boots and generates keys. It will then switch to a distinct **double-blink heartbeat rhythm**.
3. **The Flatline:** At exactly the 5-minute mark, the green LED will turn off completely. The filesystem is now completely unmounted. **It is now 100% safe to pull the power cable.**

---

### 🎛️ Step 3: File Interception on Windows via DiskInternals Linux Writer
1. Remove the MicroSD card from the Pi and connect it to your Windows machine.
2. Launch **DiskInternals Linux Writer**.
3. Locate the **`ext4` rootfs partition** (typically the second, larger partition on the storage card).
4. Navigate down the directory structure to `/etc/config/`.

#### Task A: Modify the Wireless Matrix (`/etc/config/wireless`)
Open the `wireless` file using your text editor. Map the USB adapter hardware path to act as the station (`sta`) client, and the internal SDIO hardware path to act as the Access Point (`ap`). Change both interfaces to `option disabled '0'`.

```text
config wifi-device 'radio0'
	option type 'mac80211'
	option path 'platform/soc/3f980000.usb/usb1/1-1/1-1.2/1-1.2:1.0' # USB Hub Path
	option band '6g'
	option channel 'auto'
	option htmode 'HE80'
	option disabled '0'

config wifi-iface 'wificlient_usb'
	option device 'radio0'
	option network 'wwan'
	option mode 'sta'
	option ssid 'YOUR_UPSTREAM_SSID'
	option encryption 'psk2'
	option key 'YOUR_UPSTREAM_PASSWORD'

config wifi-device 'radio1'
	option type 'mac80211'
	option path 'platform/soc/3f300000.mmcnr/mmc_host/mmc1/mmc1:0001/mmc1:0001:1' # SDIO Path
	option band '2g'
	option channel '1'
	option htmode 'HT20'
	option disabled '0'

config wifi-iface 'default_radio1'
	option device 'radio1'
	option network 'lan'
	option mode 'ap'
	option ssid 'OpenWrt-Zero2W'
	option encryption 'psk2'
	option key 'YOUR_LOCAL_AP_PASSWORD'
```

#### Task B: Modify the Network Routing & Subnet Separation (`/etc/config/network`)
Open the `network` file. Shift the target local LAN interface down to an independent subnet (e.g., `172.18.4.1`) to completely avoid conflicts with upstream networks. Declare the corresponding virtual `wwan` interface at the bottom.

```text
config interface 'loopback'
	option device 'lo'
	option proto 'static'
	option ipaddr '127.0.0.1'
	option netmask '255.0.0.0'

config globals 'globals'
	option ula_prefix 'fd65:b2d7:bde2::/48'

config device
	option name 'br-lan'
	option type 'bridge'
	list ports 'eth0'

config interface 'lan'
	option device 'br-lan'
	option proto 'static'
	option ipaddr '172.18.4.1'
	option netmask '255.255.255.0'
	option ip6assign '60'

config interface 'wwan'
	option proto 'dhcp'
```
5. Save all modifications and securely save/write them back to the MicroSD disk using **DiskInternals Linux Writer**.

---

### 🚀 Step 4: Final Initialization & Network Activation
1. Reinsert the card into the Pi Zero 2 W and apply power.
2. Connect a client device (laptop or smartphone) to the newly broadcasted **`OpenWrt-Zero2W`** Wi-Fi access point.
3. Open a browser and target the custom gateway IP address: **`http://172.18.4.1`**.
4. Log into LuCI (leave the password field blank on the very first attempt).
5. Navigate to **Network ➔ Interfaces ➔ WWAN (Edit) ➔ Firewall Settings** and place the interface into the **`wan`** zone. Save and apply all pending structural changes. 

The Pi will immediately bridge the traffic routing lanes, creating full internet passthrough.

#### 🛡️ Step 5: Global Environment Alignment
Force OpenWrt to permanently use `nano` as the global system default text editor for all administration tasks moving forward:

```bash
echo "export EDITOR=nano" >> /etc/profile
source /etc/profile
```



# Raspberry Pi Zero 2 W Travel Router with Tailscale & OpenWrt

This guide explains how to convert a Raspberry Pi Zero 2 W into a secure travel router. By routing all client traffic through a home exit node, connected devices (like a Surface Pro X) can browse securely from public Wi-Fi while appearing to be on your home network.

Because the Pi Zero 2 W has limited CPU power, running Tailscale permanently will drain resources and slow down the local network. Leaving it off by default also lets you share the base OpenWrt Access Point details with others without exposing private home network routes. 

To solve this, we configure an on/off toggle switch using a custom menu action button inside the LuCI web interface.

---

## 🛠️ Step 1: Install the Packages

Once your Pi is connected to the internet via the USB card, go to **System** ➔ **Software** in LuCI (or log in via SSH) and install these four essential components:

* `tailscale` – The core VPN daemon.
* `kmod-tun` – The Linux virtual network driver required by Tailscale.
* `iptables-nft` – Ensures OpenWrt handles Tailscale's firewall rules properly.
* `luci-app-commands` – Adds a custom menu to LuCI to build web buttons.

---

## 🔗 Step 2: Establish the Home Link (One-Time Setup)

Run this command once via SSH to link your OpenWrt device to your Tailscale account. 

> [!NOTE]  
> If you are concerned about being locked out of the internet when the tunnel becomes active, you can perform this step **after** completing the Firewall Bridge step (Step 4).

Replace `YOUR-HOME-EXIT-NODE-IP` with your home machine's `100.x.x.x` Tailscale IP address.

```bash
# Start and enable the service
/etc/init.d/tailscale start
/etc/init.d/tailscale enable

# Authenticate and map to your exit node
tailscale up --accept-dns=false --exit-node=YOUR-HOME-EXIT-NODE-IP --exit-node-allow-lan-access=true
```

1. Follow the authentication link printed on the screen to approve the router in your browser. 
2. Once authenticated, run the following command to turn it off immediately:
   ```bash
   tailscale down
   ```

---

## 🎛️ Step 3: Create the On/Off Switch in LuCI

Rather than opening a terminal whenever you want to toggle the VPN, you can create a point-and-click dashboard directly inside the web interface using **Custom Commands**.

1. In the LuCI menu, navigate to **System** ➔ **Custom Commands**.
2. Click **Add** to create the "VPN On" button:
   * **Description:** `Start Tailscale Home Tunnel`
   * **Command:** `tailscale up --accept-dns=false --exit-node=YOUR-HOME-EXIT-NODE-IP --exit-node-allow-lan-access=true`
3. Click **Add** again to create the "VPN Off" button:
   * **Description:** `Stop Tailscale Tunnel`
   * **Command:** `tailscale down`
4. Click **Save & Apply**.

Now, when you visit **System** ➔ **Custom Commands**, your two actions will be neatly presented. Clicking **Run** next to *Start Tailscale* will instantly drop all connected Wi-Fi devices into the secure encrypted tunnel. Clicking *Stop Tailscale* drops the connection instantly, returning the AP to standard local routing.

---

## 🧱 Step 4: The Firewall Bridge

For OpenWrt to forward your local wireless devices (`172.18.4.x`) into the Tailscale connection when it is active, the firewall needs an interface definition.

1. Go to **Network** ➔ **Interfaces** and click **Add new interface...**
2. Configure the following fields:
   * **Name:** `tailscale`
   * **Protocol:** `Unmanaged`
   * **Device:** `tailscale0`
3. Click **Create Interface**.
4. Go to the newly created interface's **Firewall Settings** tab, and assign it to the **`wan` zone** alongside your USB client interface.
5. Click **Save**, and then click **Save & Apply**.


# 🔋 Hardware Protection via Waveshare 18650 UPS HAT

To prevent storage and configuration file corruption on the road, a lightweight background monitor runs via OpenWrt's native scheduler (`cron`). This monitors the dual 18650 series cells via the onboard `INA219` sensor chip at I2C address `0x42` and triggers a clean system shutdown before the battery dies.

### 🛠️ 1. Enable Hardware I2C Interface
OpenWrt does not enable the Broadcom serial buses by default. Edit the primary boot configuration file:

```bash
nano /boot/config.txt
```

Append the following hardware overlay parameters to the bottom of the file:

```text
dtparam=i2c_arm=on
dtoverlay=i2c-rtc,ds1307
```

*Save and reboot the system (`reboot`) to load the hardware profile lines.*

### 📦 2. Install Lightweight Python & I2C Modules
To keep the RAM footprint minimal on the Pi's 512MB stack, install the stripped-down, bare-bones version of Python and its SMBus bindings:

```bash
opkg update
opkg install kmod-i2c-bcm2835 i2c-tools python3-light python3-smbus
```
---
Verify that the kernel successfully maps the Waveshare hardware chip by scanning the active bus:

```bash
i2cdetect -y 1
```
*(You should see hexadecimal address `42` illuminate within the `40:` row grid layout).*

```text
     0  1  2  3  4  5  6  7  8  9  a  b  c  d  e  f
00:          -- -- -- -- -- -- -- -- -- -- -- -- -- 
10: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- 
20: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- 
30: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- 
40: -- -- 42 -- -- -- -- -- -- -- -- -- -- -- -- -- 
```

### 📜 3. Inject the Core UPS Guard Script
Create a tiny monitoring executable asset at `/etc/ups_monitor.py`:

```bash
nano /etc/ups_monitor.py
```

Paste the following logic, specifically calibrated for the dual 18650 series cell pack configurations (8.4V full load / 6.4V cut-off boundary):

```python
#!/usr/bin/env python3
import smbus
import os
import sys

I2C_BUS = 1
UPS_ADDRESS = 0x42      
REG_BUS_VOLTAGE = 0x02  

# Critical Threshold (3.2V per cell minimum backup safety buffer)
CRITICAL_VOLTAGE = 6.4 

def get_pack_voltage():
    try:
        bus = smbus.SMBus(I2C_BUS)
        read_data = bus.read_i2c_block_data(UPS_ADDRESS, REG_BUS_VOLTAGE, 2)
        raw_val = (read_data[0] << 8) | read_data[1]
        voltage = (raw_val >> 3) * 0.004
        return voltage
    except Exception:
        return None

pack_voltage = get_pack_voltage()

if pack_voltage is not None:
    if pack_voltage <= CRITICAL_VOLTAGE:
        os.system("logger 'UPS 18650 voltage critically low. Executing clean poweroff.'")
        os.system("/sbin/poweroff")
        sys.exit(0)
```

Make the script executable:
```bash
chmod +x /etc/ups_monitor.py
```

### ⏱️ 4. Automate the Scan via Cron Tasks
Instead of running a persistent background engine thread that consumes memory, delegate execution to the native lightweight cron scheduler to check the status once every minute or longer.
From the Terminal...
```bash
echo "*/5 * * * * /usr/bin/python3 /etc/ups_monitor.py" >> /etc/crontabs/root
```

Restart the background scheduler engine to apply:
```bash
/etc/init.d/cron restart
```
***

### ⚠️ A Small Code Adjustment Notice for your File:
The `smbus.read_i2c_block_data` tool pulls data as a structured list of bytes (`[byte1, byte2]`), so wrapping it with index tags like `[0]` and `[1]` ensures that the Python engine can shift the bits correctly without throwing a type error!

### 📊 5. Optional: LuCI Visual Battery Dashboard Status Check
To view real-time battery voltage and estimated capacities directly from the LuCI web panel without terminal use:

1. Build an execution script at `/etc/ups_status.py` with executable permissions (`chmod +x`).
2. Map the script inside the web framework: **System ➔ Custom Commands ➔ Add**:
   * **Description:** Check UPS Battery Status
   * **Command:** `/etc/ups_status.py`

When triggered, it parses the binary register values and delivers a clean status window directly within the web dashboard.
Create a tiny executable asset at `/etc/ups_status.py`:

```bash
nano /etc/ups_status.py
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
chmod +x /etc/ups_status.py
```

### 🔄 Staging the Unified Tailscale Toggle Script

Before mapping the interactive sidebar application links, you must deploy the unified toggle engine script onto the Pi's filesystem. This script automatically checks if the VPN daemon is active, tears down routing tables on disconnection, or brings up the interface using your custom exit node configurations seamlessly.

1. Connect to your Pi's web console or SSH and create the controller file:
   ```bash
   nano /etc/toggle_tailscale.sh
   ```

2. Paste the following unified execution code into the file:
   ```bash
   #!/bin/sh

   # Check if the Tailscale daemon is currently running
   if pgrep tailscaled > /dev/null; then
       echo "Tailscale is active. Disconnecting from tailnet..."
       /usr/sbin/tailscale down 2>/dev/null
       
       echo "Stopping Tailscale daemon..."
       /etc/init.d/tailscale stop >/dev/null 2>&1
       echo "Tailscale has been cleanly stopped."
   else
       echo "Tailscale is offline. Starting daemon..."
       /etc/init.d/tailscale start >/dev/null 2>&1
       
       echo "Waiting 3 seconds for daemon initialization..."
       sleep 3
       
       echo "Bringing Tailscale interface up with custom routing..."
       # Run the up command and mute the background Go log runtime clutter
       /usr/sbin/tailscale up --accept-dns=false --exit-node=100.111.96.59 --exit-node-allow-lan-access=true 2>/dev/null
       
       echo "Tailscale is now up and running successfully."
       
       echo "----------------------------------------"
       echo "Current Tailscale IP:"
       /usr/sbin/tailscale ip -4
       echo "----------------------------------------"
   fi
   ```

3. Save the file and grant it explicit execution permissions:
   ```bash
   chmod +x /etc/toggle_tailscale.sh
   ```


## 🚀 Bonus Extension: Creating a Custom LuCI Sidebar Menu ("Travel Tools")

If you want to move beyond basic Custom Commands and give your headless travel router a highly polished, integrated interface look, you can map your custom scripts directly into LuCI's primary left-hand navigation sidebar. 

This creates a new **"Travel Tools"** main category with two dedicated sub-panels: **"Toggle Tailscale"** and **"UPS Battery Status"**.

### 📁 1. Define the Menu Framework Structure
Create the structural configuration JSON schema layout file on the filesystem:

```bash
nano /usr/share/luci/menu.d/luci-app-travel-tools.json
```

Paste the following mapping coordinates inside the file:

```json
{
	"admin/travel_tools": {
		"title": "Travel Tools",
		"order": 60,
		"action": {
			"type": "firstchild"
		}
	},
	"admin/travel_tools/tailscale": {
		"title": "Toggle Tailscale",
		"order": 1,
		"action": {
			"type": "view",
			"path": "travel_tools/tailscale_view"
		}
	},
	"admin/travel_tools/ups": {
		"title": "UPS Battery Status",
		"order": 2,
		"action": {
			"type": "view",
			"path": "travel_tools/ups_view"
		}
	}
}
```

### 🎛️ 2. Inject the Interactive Dashboard Views
Create a dedicated template folder structure, then build the two rendering scripts:

```bash
mkdir -p /usr/share/luci/view/travel_tools
```

#### A. Tailscale Action Controller Panel
Create the view interface engine at `/usr/share/luci/view/travel_tools/tailscale_view.js`:

```javascript
'use strict';
'use ui';

return L.view.extend({
    executeScript: function() {
        return L.resolveDefault(fs.exec('/etc/toggle_tailscale.sh'), {}).then(function(res) {
            var output = document.getElementById('script-output');
            if (res.stdout) {
                output.textContent = res.stdout;
            } else if (res.stderr) {
                output.textContent = "Error:\n" + res.stderr;
            } else {
                output.textContent = "Command executed successfully with no text return.";
            }
        });
    },

    render: function() {
        var body = E('div', { 'class': 'cbi-map' }, [
            E('h2', {}, _('Tailscale Connection Engine')),
            E('div', { 'class': 'cbi-map-descr' }, _('Click the action button below to connect or disconnect your travel router from the secure tailnet.')),
            E('div', { 'class': 'cbi-section' }, [
                E('div', { 'class': 'cbi-section-descr' }, [
                    E('button', {
                        'class': 'btn cbi-button cbi-button-action important',
                        'click': ui.createHandler(this, 'executeScript')
                    }, _('Run Tailscale Toggle Switch'))
                ]),
                E('pre', {
                    'id': 'script-output',
                    'style': 'background:#1e1e1e; color:#fff; padding:15px; border-radius:4px; font-family:monospace; white-space:pre-wrap; margin-top:15px;'
                }, _('System status idle. Click the button above to run the toggle sequence...'))
            ])
        ]);

        return body;
    }
});
```

#### B. Real-Time UPS Telemetry Screen
Create the telemetry monitor view at `/usr/share/luci/view/travel_tools/ups_view.js`:

```javascript
'use strict';
'use ui';

return L.view.extend({
    load: function() {
        return L.resolveDefault(fs.exec('/etc/ups_status.py'), {});
    },

    render: function(res) {
        var outputText = _('Error: Battery tracking execution failed.');
        if (res && res.stdout) {
            outputText = res.stdout;
        }

        var body = E('div', { 'class': 'cbi-map' }, [
            E('h2', {}, _('Hardware Energy Status Matrix')),
            E('div', { 'class': 'cbi-map-descr' }, _('Real-time bus diagnostic data pulled straight from the physical Waveshare 18650 I2C registers.')),
            E('div', { 'class': 'cbi-section' }, [
                E('pre', {
                    'style': 'background:#1e1e1e; color:#00ff00; padding:20px; border-radius:4px; font-family:monospace; white-space:pre-wrap; font-size:1.1em; line-height:1.4;'
                }, outputText),
                E('div', { 'class': 'cbi-section-descr', 'style': 'margin-top:10px;' }, [
                    E('button', {
                        'class': 'btn cbi-button cbi-button-neutral',
                        'click': function() { location.reload(); }
                    }, _('Refresh Battery Metrics'))
                ])
            ])
        ]);

        return body;
    }
});
```

### ⚡ 3. Apply the Blueprint Expansion Layout
Flush the active structural UI index mapping caches via SSH so the web server can pick up your new files immediately:

```bash
rm -rf /tmp/luci-indexcache /tmp/luci-modulecache
```

*Refresh your web browser to reveal your new customized travel dashboard control cluster seamlessly loaded into the primary navigation menu.*


## 🤝 Acknowledgements

- **Mediatek Wi-Fi USB Driver Configuration:** Shoutout to monotux.tech for documenting the necessary kernel modules (`kmod-mt7921u` & firmware blobs) required to get these Wi-Fi 6 adapters working smoothly on OpenWrt setups.
- **Architectural & AI Collaboration:** Structured, optimized, and debugged in collaboration with Google's AI assistant framework to ensure robust, non-interactive script operations and fail-safe terminal tracking protocols.

