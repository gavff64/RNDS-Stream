# RNDS-Stream
An experimental DSi remote game streaming homebrew application written with [RubyNDS](https://github.com/gavff64/RubyNDS)

https://github.com/user-attachments/assets/d5ebbbf0-7754-46ff-a59c-b0adca8d20d1

## How does it work?
My DSi homebrew SDK [RubyNDS](https://github.com/gavff64/RubyNDS) contains support for JPEGDEC, a tiny fast JPEG decoder. Using this we can easily get MJPEG working, a format that is already used for basic video streaming.

With just the right GStreamer settings, we can pull off a playable 20 fps of relatively low-latency streaming (with frameskipping). Quality settings can easily be changed within the GStreamer helper script. Full DSi resolution does run but more so at 10 - 15 fps.

Mouse and keyboard control are done with ydotool. I'm using my simple wrapper for this [Rubydotool](https://github.com/gavff64/Rubydotool). Ydotool requires user permissions to work which is talked about in the setup.

Your steam library and prism launcher instances are automatically scanned.

## Setup

> [!NOTE]
> This was only tested on Fedora KDE. Window parsing only works on X11/xWayland. Pure Wayland windows will not be detected. Server will run on the local network, there are zero security implementations, so it is not recommended to truly run this remotely over the internet.

1. Check whether your PC can send keyboard and mouse input:

    ```sh
    test -w /dev/uinput && echo "Ready" || echo "Setup needed"
    ```
    
    If it says `Ready`, skip to the next step. If it says `Setup needed`, run:
    
    ```sh
    printf '%s\n' 'KERNEL=="uinput", SUBSYSTEM=="misc", TAG+="uaccess", OPTIONS+="static_node=uinput"' | sudo tee /etc/udev/rules.d/60-rnds-stream-uinput.rules >/dev/null
    sudo udevadm control --reload-rules
    sudo reboot
    ```
    
2. Put `RNDS-Stream.nds` on your flashcart's microSD card. Create `rnds-stream.txt` at the root of the same card with only your PC's local IP address, for example:

   ```text
   192.168.1.100
   ```

   The ROM reads this file through `fat:/`, so it needs to be on the card used by the flashcart, not the DSi's internal SD card. (this should be easy to change in the source code if you're not using a flashcart)

3. Install `wmctrl` and GStreamer on the PC. The Flatpak uses the host tools to capture game windows. On Fedora:

   ```sh
   sudo dnf install wmctrl gstreamer1 gstreamer1-plugins-good
   ```

4. Install and run the Flatpak on the PC:

   ```sh
   flatpak install --user RNDS-Stream.flatpak
   flatpak run io.github.gavff64.RNDSStream
   ```

5. Open `RNDS-Stream.nds` on the DSi and choose a game.

## Limitations and Issues

- [ ] Server doesn't seem to recognize when the client disconnects.
- [ ] Possible fundamental 20 fps cap because of decode speed?
- [ ] Server needs to be manually restarted from the PC in order to switch games.
- [ ] Hardcoded keybinds.
- [ ] Inherent limited resolution. Text and UI is hard to see.
- [ ] Mouse needs to be locked to the window.
