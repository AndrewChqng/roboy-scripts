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

## KDE Plasma / Wayland: Custom Touchpad Gestures

Touchpad gestures for volume, isolated internal brightness, and media control have been separated into a dedicated repository:
👉 **[AndrewChqng/kde-wayland-gestures](https://github.com/AndrewChqng/kde-wayland-gestures)**

---

### Credits & Disclaimers

- **AI Assistance**: Documented and verified with assistance from Antigravity (Google DeepMind) by inspecting `kscreen-doctor` CLI parameters and KWin Wayland display configuration schemas.
- **Disclaimer**: Custom display timings and refresh rate modifications interact directly with display hardware and panel timing limits. Applying unsupported refresh rates or out-of-spec timings can lead to black screens, signal instability, or potential display hardware damage. Experimental use only; use at your own discretion.


