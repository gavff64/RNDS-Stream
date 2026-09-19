HOST = "192.168.12.189"

stream = HTTP.get(HOST, port: 8080, stream: true)
video = Draw.load(stream) # constant stream of bytes regardless if compeleted, not completed, over completed. Wrapper ensures we only work with 1 jpeg at a time.
Draw.stretch(205, 154, :top)

fps = FPS.new
stream.write("0\n") # ask for the first frame, nothing held

while System.main_loop?
  frame = video.read # either returns a complete jpeg or nil (this is from MJPEG#read)
  break unless frame # kill the loop if video.read returns nil

  Input.update
  stream.write("#{Input.held}\n") # send the held buttons and ask for the next frame BEFORE drawing this one, so the server works while the ds decodes

  Draw.image(Draw.load(frame), 0, 0) # load the frame, then display, instead of using Draw.video because of ^^^

  fps.tick
end
