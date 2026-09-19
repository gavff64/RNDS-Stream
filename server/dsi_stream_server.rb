# These are my notes just to ensure I fully understand everything going on. Optimizing this is difficult. -gavff

require "open3"
require "socket"
require "rubydotool"
require_relative "gstreamer_helper"
require_relative "jpeg_helper"
require_relative "steam_list"

window = steam_find_launch # wmctrl is x11/xwayland only so probably wanna replace with something better eventually

PROGRAM = window.split[3..-1].join(" ") # server should restart (at some point, not implemented) when client restarts so a constant is fine. Parses name from wmctrl.

# match dsi button bit values (listed in rubynds input mrbgem) with the keycodes.json from rubydotool. (ds only sends a single number to server per event)
CONTROLS = {
  1 << 6 => :w, # KEY_UP
  1 << 7 => :s, # KEY_DOWN
  1 << 5 => :a, # KEY_LEFT
  1 << 4 => :d,  # KEY_RIGHT
  1 << 0 => :space # KEY_A
}

begin
  raise if window.nil?
rescue RuntimeError => e
  puts "'#{PROGRAM}' not found."
  exit
end

puts "Successfully started streaming..."
puts "Control + C to stop."

mjpeg = gstreamer(window.split[0].to_i(16)) # gstreamer wants hexidecimal xid (window id, kinda), so convert wmctrl value

latest_frame = nil
frame_number = 0
frame_mutex = Mutex.new # capture thread and main server thread both work with latest_frame/frame_number, so mutex is needed for proper syncing.

capture = Thread.new do
  Open3.pipeline_r(mjpeg) do |stream| # start gstreamer command built by helper, stream it's output.
    stream.binmode # set IO stream to binary mode rather than text (possibly not required on linux anyway)
    data = "".b # assign data to a blank string with its encoding forced to binary

    # data buffer
    loop do
      chunk = stream.readpartial(16384) # send whatever is available immediately, up to 16,384 bytes.
      data << chunk

      while frame = jpeg_frame(data)
        frame_mutex.synchronize do
          latest_frame = frame
          frame_number += 1
        end
      end
    end
  rescue EOFError # EOFError is raised when gstreamer dies. Handles this.
  end
end

server = TCPServer.new("0.0.0.0", 8080)
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

sent = 0
previous = 0
Rubydotool.start # boot the ydotool daemon once

loop do
  line = client.gets # the DSi sends its held buttons with every frame request.
  break if line.nil? # stop if connection is closed.

  held = line.to_i
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
