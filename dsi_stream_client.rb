HOST = "192.168.12.189"

stream = HTTP.get(HOST, port: 8080, stream: true)
video = Draw.load(stream) # constant stream of bytes regardless if compeleted, not completed, over completed. Wrapper ensures we only work with 1 jpeg at a time.
Draw.stretch(205, 154, :top)

fps = FPS.new
last_x = 0
last_y = 0
touching = false

stream.write("0,0,0\n") # ask for the first frame, nothing held, no touch movement

while System.main_loop?
  frame = video.read # either returns a complete jpeg or nil (this is from MJPEG#read)
  break unless frame # kill the loop if video.read returns nil

  Input.update
  dx = 0
  dy = 0

  if Input.touch?
    if touching # only report movement if the last frame was also a touch, otherwise re-touching elsewhere would jump the mouse
      dx = Input.touch_x - last_x
      dy = Input.touch_y - last_y
    end

    touching = true
    last_x = Input.touch_x
    last_y = Input.touch_y
  else
    touching = false
  end

  stream.write("#{Input.held},#{dx},#{dy}\n") # send buttons and touch movement, and ask for the next frame BEFORE drawing this one, so the server works while the ds decodes

  Draw.image(Draw.load(frame), 0, 0) # load the frame, then display, instead of using Draw.video because of ^^^

  fps.tick
end
