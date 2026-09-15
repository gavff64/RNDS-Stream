# "\xFF\xD8" is the 2 byte marker in every JPEG file that represents the start of an image
# "\xFF\xD9" is the end of an image.

def jpeg_frame(data)
  first = data.index("\xFF\xD8".b) # for example if the image starts at index position 10, then first == 10.
  return unless first

  last = data.index("\xFF\xD9".b, first + 2) # "first + 2" because the starting marker itself is 2 bytes. So starting at byte 12, search for the end.
  return unless last

  frame = data.byteslice(first, last - first + 2) # start at index position 10, slice to the end, that's a full frame. (returns a string)
  data.slice!(0, last + 2) # JPEG was copied into frame, so remove those bytes from the data buffer.
  frame
end
