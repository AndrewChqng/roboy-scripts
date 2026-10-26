# roboy-scripts
useful andrew scripts
likely chatgpt generated

---

## KDE Plasma / Wayland: Custom Display Modes (`kscreen-doctor`)

Notes and instructions for adding, managing, switching, and removing custom display resolutions and refresh rates on KDE Plasma (Wayland) using `kscreen-doctor`.

### 1. Adding a Custom Mode

#### Syntax
```bash
kscreen-doctor output.<name_or_id>.addCustomMode.<width>.<height>.<refresh_rate_in_mHz>.<blanking>
```

#### Example
```bash
kscreen-doctor output.eDP-1.addCustomMode.1920.1200.70000.reduced
```

#### What each parameter does
- **`<name_or_id>`**: The display output name (e.g., `eDP-1`, `HDMI-A-1`) or numeric output ID (e.g., `1`), visible via `kscreen-doctor -o`.
- **`<width>` & `<height>`**: Resolution dimensions in pixels (e.g., `1920` width and `1200` height).
- **`<refresh_rate_in_mHz>`**: Target refresh rate in milliHertz (mHz), where $1\text{ Hz} = 1000\text{ mHz}$.
  - $60\text{ Hz} \rightarrow 60000$
  - $70\text{ Hz} \rightarrow 70000$
  - $75\text{ Hz} \rightarrow 75000$
- **`<blanking>`**: The blanking standard timing calculation to use:
  - `reduced` (CVT-RB): Reduced blanking formula. Reduces the horizontal and vertical blanking intervals, saving pixel clock bandwidth. Recommended for modern LCD/OLED panels and display refresh rate overclocks.
  - `full` (Standard CVT): Standard VESA Coordinated Video Timing blanking intervals, typical for older CRT or legacy displays.

#### What happens behind the scenes
- KWin computes the CVT timing modeline (pixel clock frequency, horizontal/vertical totals, sync end/start).
- The custom mode is registered dynamically with the compositor and appended to the display's available modes.
- Persistent configuration is saved in `~/.config/kwinoutputconfig.json` under the connector's `customModes` array.

---

### 2. Checking Current Outputs and Modes

To inspect displays, active modes, and custom mode index numbers:

```bash
kscreen-doctor -o
```

Example snippet:
```text
Output: 1 eDP-1 ...
    Modes:  1:1920x1200@60.00!  ...  26:1920x1200@69.98  27:1920x1200@69.98* 
    Custom modes:
        0: 1920x1200@23.94
        ...
        10: 1920x1200@69.98
        11: 1920x1200@69.98
```
- `!` indicates the preferred / native mode.
- `*` indicates the currently active mode.
- The numbers listed under **Custom modes** (`0`, `1`, ..., `10`, `11`) are the zero-based indices needed for removal.

---

### 3. Removing Custom Modes

> [!IMPORTANT]
> `kscreen-doctor` does **not** accept the resolution string to remove a custom mode (e.g., `removeCustomMode.1920.1200...` does not exist).
> You must specify the **index** from the `Custom modes:` list shown by `kscreen-doctor -o`.

#### Syntax
```bash
kscreen-doctor output.<name_or_id>.removeCustomMode.<index>
```

#### Best Practices
1. **Remove higher indices first**: When removing multiple custom modes, remove in descending order (e.g., `11` then `10`) so subsequent list indices do not shift during execution.
2. **Safely switch if mode is active**: If you are removing a custom mode that is currently active (`*`), combine the command to switch back to a stable standard mode (such as mode `1` / 60 Hz) in the same atomic call:

```bash
kscreen-doctor output.eDP-1.mode.1 output.eDP-1.removeCustomMode.11 output.eDP-1.removeCustomMode.10
```

---

### 4. Moving / Switching Modes & Combining Commands

`kscreen-doctor` processes arguments **atomically in a single invocation**. Multiple display modifications can be chained together without intermediate flickers or partial applications.

#### Switching / Moving between modes
```bash
# By mode ID (found via kscreen-doctor -o)
kscreen-doctor output.eDP-1.mode.1

# By resolution and refresh rate string
kscreen-doctor output.eDP-1.mode.1920x1200@60
```

#### Chaining multiple commands
```bash
kscreen-doctor output.eDP-1.mode.1 output.eDP-1.position.0,0 output.HDMI-A-1.enable
```

---

## KDE Plasma / Wayland: Custom Touchpad Gestures (`InputActions`)

Instructions for configuring custom multi-finger gestures on KDE Plasma 6 (Wayland) to control volume, internal screen brightness, and media playback.

### Gestures Mapped
- **4 Fingers Swipe Up / Down**: Continuous Volume control (`volumeup` / `volumedown`)
- **4 Fingers Swipe Left / Right**: Internal Laptop Display Brightness only (via PowerDevil DBus)
- **4 Fingers Tap**: Media Play / Pause toggle (`playpause`)

### 1. Installation
Install `inputactions-kwin` (available on Arch / CachyOS via chaotic-aur / AUR):

```bash
sudo pacman -S inputactions-kwin inputactions-kwin-alpm-hook
```

> [!NOTE]
> Installing `inputactions-kwin-alpm-hook` is strongly recommended. KWin C++ effect plugins enforce an exact binary ABI match (`EffectPluginFactory6.x.y`). Whenever KDE Plasma updates KWin, `inputactions-kwin` must be updated or rebuilt, otherwise it will fail to load on boot (see [KWin Version Upgrades & Boot Failures](#nuance-1-kwin-version-upgrades--boot-failures)).

### 2. Configuration
Copy the configuration template [`inputactions-config.yaml`](inputactions-config.yaml) to `~/.config/inputactions/config.yaml`:

```bash
mkdir -p ~/.config/inputactions
cp inputactions-config.yaml ~/.config/inputactions/config.yaml
```

### 3. Enable Plugin in KWin
Enable the effect immediately in KWin:

```bash
qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.loadEffect kwin_gestures
```

Ensure it persists across reboots:

```bash
kwriteconfig6 --file kwinrc --group Plugins --key kwin_gesturesEnabled true
```

### 4. Enable Tap Detection Permissions (udev)
While swipe gestures are handled by KWin's compositor gesture engine, multi-finger **tap** detection requires raw `libevdev` event reading. Grant your user session access to touchpad devices:

```bash
echo 'ENV{ID_INPUT_TOUCHPAD}=="1", TAG+="uaccess"' | sudo tee /etc/udev/rules.d/71-touchpad.rules && sudo udevadm trigger
```

### 5. Reloading Configuration
To reload or verify your configuration at any time:

```bash
inputactions config reload
inputactions config issues
```

> [!NOTE]
> `inputactions config reload` requires the KWin effect (`kwin_gestures`) to already be loaded. If you see `Failed to connect to the InputActions DBus interface`, ensure the effect is active via `qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.loadEffect kwin_gestures`.

---

### Nuances & Troubleshooting

#### Nuance 1: KWin Version Upgrades & Boot Failures
KWin C++ effect plugins (`kwin_gestures.so`) bind to the exact KWin internal factory version string (e.g. `org.kde.kwin.EffectPluginFactory6.8.1`).
- **Symptom**: After a system update that upgrades `kwin`, gestures silently stop working on boot. Inspecting logs (`journalctl --user -b -u plasma-kwin_wayland.service`) reveals:
  ```text
  Effect "kwin_gestures" was built for a different version of KWin and needs to be rebuilt, expected "org.kde.kwin.EffectPluginFactory6.8.1" got "org.kde.kwin.EffectPluginFactory6.8.0"
  ```
- **Fix**: Update or rebuild `inputactions-kwin` against the new `kwin` version:
  ```bash
  sudo pacman -Sy inputactions-kwin
  # or rebuild via AUR if not yet built in repository:
  yay -S --rebuild inputactions-kwin
  ```
- Installing `inputactions-kwin-alpm-hook` sets up an automated pacman hook that alerts you whenever a KWin upgrade requires updating this package.

#### Nuance 2: Brightness Control on Multi-Monitor Setups
- **Problem**: Emitting generic keyboard keys (`brightnessup` / `brightnessdown`) triggers KDE PowerDevil's global brightness logic. In Plasma 6, PowerDevil broadcasts key events to **all** connected displays (including external monitors supporting DDC/CI or software brightness).
- **Solution**: The configuration in [`inputactions-config.yaml`](inputactions-config.yaml) avoids `keyboard: [ brightnessup ]` and instead invokes KDE's PowerDevil DBus interface directly via `busctl`:
  - It queries `org.kde.ScreenBrightness.Display.IsInternal` across available displays (`DisplaysDBusNames`).
  - It targets the internal panel (typically `display0` / `eDP-1`) with `org.kde.ScreenBrightness.Display.SetBrightness`.
  - Passing `flags = 0` preserves KDE's native on-screen display (OSD) slider, while completely isolating brightness changes from external monitors.

#### Nuance 3: KDE Native Gesture Conflicts
By default, KDE Plasma maps 4-finger vertical swipes to *Overview* and *Desktop Grid*.
- `inputactions-kwin` intercepts gestures before KWin's built-in handlers when gestures match.
- If conflicts occur, disable *Overview* / *Desktop Grid* under **System Settings** ➔ **Window Management** ➔ **Desktop Effects** (or assign them to keyboard shortcuts).

---

### Credits & Disclaimers

- **AI Assistance**: Documented and implemented with assistance from Antigravity (Google DeepMind) by analyzing KWin Wayland gesture architectures and configuring InputActions.
- **Disclaimer**: System configurations, hardware udev permissions, and custom display timings interact directly with hardware drivers and compositor components. Experimental use only; use at your own discretion.

