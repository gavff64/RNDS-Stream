# Comments are purely for me, especially on the actual capture portion, it's very tricky.

require "open3"
require "socket"
require_relative "gstreamer_helper"
require_relative "jpeg_helper"

puts "Enter program name to capture: "
print "Enter: "
PROGRAM = gets.chop.chomp.downcase # server restarts when client restarts so a constant is fine

window = `wmctrl -l`.downcase.lines.find {|line| line.include?(PROGRAM)} # wmctrl is x11/xwayland only so probably wanna replace with something better eventually

begin
  raise if window.nil?
rescue RuntimeError => e
  puts "'#{PROGRAM}' not found."
  exit # goofy, temporary. Why is this a rescue then lol
end

mjpeg = gstreamer(window.split[0].to_i(16)) # gstreamer wants hexidecimal xid (window id, kinda)

latest_frame = nil
frame_number = 0
frame_mutex = Mutex.new # capture thread and main server thread both work with latest_frame/frame_number, so mutex is needed for proper syncing.
capture = Thread.new do
  Open3.pipeline_r(mjpeg) do |stream| # start gstreamer command built by helper, stream it's output.
    stream.binmode # set IO stream to binary mode rather than text (possibly not required on linux anyway)
    data = "".b # assign data to a blank string with its encoding forced to binary

    # data buffer 4096 bytes at a time
    while chunk = stream.read(4096)
      data << chunk

      while frame = jpeg_frame(data)
        frame_mutex.synchronize do
          latest_frame = frame
          frame_number += 1
        end
      end
    end
  end
end

server = TCPServer.new("0.0.0.0", 8080)
client = server.accept

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

# send one raw jpeg after the DSi requests it. DSi decodes on device.
sent = 0

loop do
  ready = client.read(1) # wait until the DSi sends one byte.
  break if !ready || ready.empty? # stop if connectionis closed.

  frame = nil # the jpeg frame to send.
  number = nil # that jpeg's frame number.

  until frame
    frame_mutex.synchronize do
      if latest_frame && frame_number != sent
        frame = latest_frame
        number = frame_number
      end
    end
    Thread.pass unless frame
  end

  client.write(frame)
  sent = number # store which frame was sent so that you don't send the same frame again.
end
