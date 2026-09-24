# These are my notes just to ensure I fully understand everything going on. Optimizing this is difficult. -gavff

require "open3"
require "socket"
require "rubydotool"
require_relative "gstreamer_helper"
require_relative "jpeg_helper"
require_relative "steam_list"
require_relative "prism_list"

Game = Struct.new(:source, :name, :match, :command)
GAMES = steam_games + prism_games

# match dsi button bit values (listed in rubynds input mrbgem) with the keycodes.json from rubydotool. (ds only sends a single number to server per event)
CONTROLS = {
  1 << 6 => :w, # KEY_UP
  1 << 7 => :s, # KEY_DOWN
  1 << 5 => :a, # KEY_LEFT
  1 << 4 => :d,  # KEY_RIGHT
  1 << 0 => :space, # KEY_A
  1 << 1 => :left_shift, # KEY_B
  1 << 10 => :e, # KEY_X
  1 << 11 => :left_ctrl, # KEY_Y
  1 << 3 => :escape, # KEY_START
  1 << 2 => :tab # KEY_SELECT
}

# ydotool's 1 byte formatting to indicate left/right click up and down
MOUSE = {
  1 << 9 => { down: "0x40", up: "0x80" }, # KEY_L
  1 << 8 => { down: "0x41", up: "0x81" }  # KEY_R
}

MOUSE_SPEED = 2 # touch movement is in DS pixels, this scales it to "mouse counts". It's a multiplier, kinda sorta sensitivity. So 2 is like a 2:1 ratio.

server = TCPServer.new("0.0.0.0", 8080)
puts "Waiting for the DS..."
client = server.accept
puts "Client connected"
client.setsockopt(Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1) # I think this barely improves performance? Sends data to the client immediately, doesn't hold or combine data.

# read then ignore the initial request from the DSi, irrelevant, just waiting for connection to complete.
while line = client.gets
  break if line == "\r\n"
end

# send a response back that the connection was successful and to expect generic binary data coming.
client.write(
  "HTTP/1.1 200 OK\r\n" \
  "Content-Type: application/octet-stream\r\n" \
  "Connection: close\r\n\r\n"
)

client.write("#{GAMES.length}\n")
GAMES.each do |game|
  client.write("#{game.source}: #{game.name}\n")
end

choice = client.gets
raise "No game selected" unless choice && choice.match?(/\Aplay \d+\n\z/)

game = GAMES[choice.split[1].to_i]
raise "Invalid game" unless game

puts "Launching #{game.name}..."
Thread.new do
  system(*game.command, out: File::NULL, err: File::NULL) # build the game launch commands and execute it
end

window = nil
until window
  window = `wmctrl -l`.downcase.lines.find { |line| line.include?(game.match.downcase) }
  sleep 2 unless window
end

puts "Successfully started streaming..."
puts "Control + C to stop."

mjpeg = gstreamer(window.split[0].to_i(16))

latest_frame = nil
frame_number = 0
frame_mutex = Mutex.new

capture = Thread.new do
  Open3.pipeline_r(mjpeg) do |stream|
    stream.binmode
    data = "".b

    loop do
      data << stream.readpartial(16384)

      while frame = jpeg_frame(data)
        frame_mutex.synchronize do
          latest_frame = frame
          frame_number += 1
        end
      end
    end
  rescue EOFError
  end
end

sent = 0
previous = 0
Rubydotool.start # boot the ydotool daemon once

loop do
  line = client.gets # the DSi sends its held buttons with every frame request.
  break if line.nil? # stop if connection is closed.

  held, dx, dy = line.split(",").map(&:to_i) # parse "line" to an array of integers. "64,5,-3\n" for example turns to [64, 5, -3], assign to held, dx, dy.
  events = []

  CONTROLS.each do |button, key|
    was_held = (previous & button) != 0
    is_held = (held & button) != 0
    next if was_held == is_held # do nothing different if the button hasn't changed from the last

    keycode = Rubydotool.find_keycode(key)

    if is_held
      state = 1
    else
      state = 0
    end

    events << "#{keycode}:#{state}" # ydotool takes "keycode:state", 1 is press, 0 is release
  end

  Rubydotool.run("key", *events) unless events.empty? # the "key" subcommand is needed for ydotool. Splat because ydotool can do multiple events in a single process.

  clicks = []

  MOUSE.each do |button, codes|
    was_held = (previous & button) != 0
    is_held = (held & button) != 0
    next if was_held == is_held

    if is_held
      state = :down
    else
      state = :up
    end

    clicks << codes[state] # 0x40/0x80 is left down/up, 0x41/0x81 is right down/up
  end

  Rubydotool.run("click", *clicks) unless clicks.empty?
  Rubydotool.run("mousemove", "--", dx * MOUSE_SPEED, dy * MOUSE_SPEED) if dx != 0 || dy != 0 # "--" is so ydotool doesn't mistake negatives for flags.
  previous = held

  frame = nil # the jpeg frame to send.
  number = nil # that jpeg's frame number.

  # ensure there is a frame, and it's actually a new frame.
  until frame
    frame_mutex.synchronize do
      if latest_frame && frame_number != sent
        frame = latest_frame
        number = frame_number
      end
    end
    Thread.pass unless frame # if nothing is new, stop wasting time and pass the turn to other threads.
  end

  client.write(frame)
  sent = number # store which frame was sent so that you don't send the same frame again.
end
