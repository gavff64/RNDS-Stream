raise "SD card unavailable" unless FS.mount

file = FS.open("fat:/rnds-stream.txt")
host = FS.read(file, 64).strip # read up to 64 bytes of the txt
FS.close(file)
raise "Server address missing" if host.empty?

stream = HTTP.get(host, port: 8080, stream: true)

def read_line(stream)
  line = ""

  loop do
    chunk = stream.read(1)
    next if chunk.nil?
    raise "Disconnected" if chunk == "" # not sure this works
    break if chunk == "\n"
    line << chunk
  end
  line
end

# figure out the number of games and repeat appending the game name to the games array that number of times
games = []
read_line(stream).to_i.times do
  games << read_line(stream)
end

raise "No games found" if games.empty?

selected = 0 # which game cursor is on
drawn = -1 # if drawn is different than selected, then that means screen needs to be redrawn to match

while System.main_loop?
  Input.update
  selected = (selected + 1) % games.length if Input.down?(KEY_DOWN)
  selected = (selected - 1) % games.length if Input.down?(KEY_UP)

  if selected != drawn
    drawn = selected
    first = selected / 18 * 18

    print "\e[2J\e[H"
    puts "Choose a game"
    puts "A: play   Up/Down: move"
    puts

    games[first, 18].each_with_index do |name, index|
      marker = first + index == selected ? "> " : "  "
      puts "#{marker}#{name[0, 29]}"
    end

    puts "#{selected + 1} / #{games.length}"
  end

  break if Input.down?(KEY_A)
  System.vblank
end

stream.write("play #{selected}\n")
print "\e[2J\e[H"
puts "Launching #{games[selected]}..."

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
