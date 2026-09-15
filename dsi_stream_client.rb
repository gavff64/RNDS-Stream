HOST = "192.168.12.189"

stream = HTTP.get(HOST, port: 8080, stream: true)
video = Draw.load(stream)
Draw.stretch(160, 96, :top)

while System.main_loop?
  stream.write("\x01") # send one byte to the server letting it know we're ready for the next frame.
  Draw.video(video)
  System.vblank
end
