VIDEO = [205, 154, 50, false, "1/1"] # NDS needs choosable settings in the client, lots of good combos for different scenarios

def gstreamer(window_id)
  width, height, quality, borders, ratio = VIDEO # ^
  mjpeg = [
    "gst-launch-1.0", "-q",
    "ximagesrc", "xid=#{window_id}", "use-damage=false", "show-pointer=true", "do-timestamp=true",
    "!", "videorate", "drop-only=true",
    "!", "video/x-raw,framerate=30/1",
    "!", "videoconvert",
    "!", "videoscale", "method=lanczos", "add-borders=#{borders}",
    "!", "video/x-raw,format=I420,width=#{width},height=#{height},pixel-aspect-ratio=#{ratio}",
    "!", "queue", "leaky=downstream", "max-size-buffers=1", "max-size-bytes=0", "max-size-time=0",
    "!", "jpegenc", "quality=#{quality}",
    "!", "fdsink", "fd=1", "sync=false", "async=false",
    {err: File::NULL} # silence gstreamer's noisy output.
  ]
end
