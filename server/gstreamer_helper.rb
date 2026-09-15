VIDEO = [160, 96, 72, false, "1/1"] # Seems to be the highest fps + highest res + highest quality combo I could get on the DSi.

def gstreamer(window_id)
  width, height, quality, borders, ratio = VIDEO # ^
  mjpeg = [
    "gst-launch-1.0", "-q",
    "ximagesrc", "xid=#{window_id}", "use-damage=false", "show-pointer=true", "do-timestamp=true",
    "!", "videorate", "drop-only=true",
    "!", "video/x-raw,framerate=30/1",
    "!", "videoconvert",
    "!", "videoscale", "method=0", "add-borders=#{borders}",
    "!", "video/x-raw,format=I420,width=#{width},height=#{height},pixel-aspect-ratio=#{ratio}",
    "!", "queue", "leaky=downstream", "max-size-buffers=1", "max-size-bytes=0", "max-size-time=0",
    "!", "jpegenc", "quality=#{quality}",
    "!", "fdsink", "fd=1", "sync=false", "async=false",
    { pgroup: true, err: File::NULL } # put spawned process into it's own group so control + c kills the entire process. Suppress noisy output with "err: File::NULL".
  ]
end
