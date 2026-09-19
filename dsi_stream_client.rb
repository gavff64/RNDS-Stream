HOST = "192.168.12.189"

stream = HTTP.get(HOST, port: 8080, stream: true)
video = Draw.load(stream)
Draw.stretch(205, 154, :top)

frames = 0
started = Timer.ms
stream.write("\x01")

while System.main_loop?
  frame = video.read
  break unless frame
  stream.write("\x01") # send one byte to the server letting it know we're ready for the next frame.
  Draw.image(Draw.load(frame), 0, 0)

  frames += 1
  now = Timer.ms
  elapsed = now - started

  if elapsed >= 1000
    print "\e[2J\e[H"
    puts "#{frames * 1000 / elapsed} FPS"
    frames = 0
    started = now
  end
end
