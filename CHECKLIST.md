# 🛠️ Headless OpenWrt Travel Router Troubleshooting Checklist

Use this checklist to systematically verify your Raspberry Pi Zero 2 W build if you lose access, experience a crash, or need to rebuild the environment from a fresh flash on the road.

---

## 💾 Phase 1: SD Card Pre-Boot (External PC Phase)
Before inserting the SD card into the Pi, verify these configurations are in place:

- [ ] **Boot Parameters Set:** The `/boot/config.txt` file (FAT32 partition) contains the hardware activation flags:
  ```text
  dtparam=i2c_arm=on
  dtoverlay=i2c-rtc,ds1307
  ```
- [ ] **First Boot Timing:** On a fresh flash, the card was inserted, booted once for **3 minutes** to let OpenWrt generate its rootfs overlay, and then safely shut down before modifications were made to the `/upper/` directory.
- [ ] **Wireless AP Pre-Staged:** `/upper/etc/config/wireless` has `option disabled '0'` and is set to your manual subnet space (e.g., `172.18.4.1`).

---

## 🐧 Phase 2: File System & Permissions (SSH Phase)
If you can connect to the router via Wi-Fi/SSH but scripts fail to run, run these checks:

- [ ] **Script Execution Flags:** Confirm all custom assets have execution permissions. Fix them by running:
  ```bash
  chmod +x /etc/toggle_tailscale.sh
  chmod +x /etc/ups_monitor.py
  chmod +x /etc/ups_status.py
  ```
- [ ] **Package Dependencies Installed:** Verify Python and I2C tools are present by running:
  ```bash
  opkg list-installed | grep -E "python3-light|python3-smbus|i2c-tools"
  ```
- [ ] **Cron Scheduler Running:** Ensure the background daemon is actively checking the battery status every 5 or 10 minutes:
  ```bash
  /etc/init.d/cron status
  ```

---

## 🔋 Phase 3: Hardware & I2C Bus Diagnostics
If battery reading errors appear in the logs or the LuCI view is blank:

- [ ] **I2C Bus Scan:** Run the bus discovery tool via SSH:
  ```bash
  i2cdetect -y 1
  ```
  * **Pass Condition:** Device Hex Address `42` appears in the `40:` row grid layout.
  * **Fail Condition:** Grid returns completely blank (`--`). Check the physical connection between the Pi and the Waveshare pins, and ensure the battery toggle switch on the HAT is flipped to **ON**.
- [ ] **Voltage Buffer Check:** Run `/etc/ups_status.py` manually. Verify the pack reading is safely above **6.4V** (3.2V per cell). If the battery is under 6.4V, the background guard script will rightfully initiate a preventative `poweroff`.

---

## 🌐 Phase 4: Tailscale Tunnel & Routing
If Tailscale initializes but traffic fails to route through your exit node:

- [ ] **Daemon Process Check:** Verify the tailscaled service engine is active:
  ```bash
  pgrep tailscaled
  ```
- [ ] **Exit Node Authentication:** Run `tailscale status` to confirm your router is cleanly authenticated to your tailnet and can see your home exit node machine (`100.111.96.59`).
- [ ] **DNS Lock Check:** If you have internet access *until* Tailscale turns on, verify your toggle script explicitly passes `--accept-dns=false` so the local hotel captive portal dns doesn't collide with the tunnel routing table.

---

## 🎨 Phase 5: Custom LuCI UI Refresh
If the **"Travel Tools"** option is completely missing from the sidebar or displays a 404 error:

- [ ] **Cache Flush Execution:** Run the cache purge string via the command line to force the web interface to recalculate your newly injected JavaScript layout files:
  ```bash
  rm -rf /tmp/luci-indexcache /tmp/luci-modulecache
  ```
- [ ] **JSON Structural Validity:** Validate that your layout configuration `/usr/share/luci/menu.d/luci-app-travel-tools.json` contains no trailing commas or broken bracket markers.
