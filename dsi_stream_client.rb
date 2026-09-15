HOST = "192.168.12.189"

stream = HTTP.get(HOST, port: 8080, stream: true)
video = Draw.load(stream)

while System.main_loop?
  Draw.video(video)
  System.vblank
end
