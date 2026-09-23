# openwrt-headless-rpi-zero2w
A foolproof method for headless OpenWrt setup using a Windows machine and DiskInternals Linux Writer
# Technical Documentation: Headless Provisioning of Raspberry Pi Zero 2 W (Dual Wi-Fi Setup via Windows Architecture)

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
