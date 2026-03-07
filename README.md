# Simple image printer

Right now it only handles PNGs. Uses the kitty terminal graphics protocol in
direct mode to print an image to the console. Honestly, the terminal does most
of the work.

The program takes the bytes of the image, base64 encodes them, chunks them, and
dumps to stdout with each chunk wrapped in the appropriate escape code.

## Todo

- Use stb_image to decode arbitrary image formats
- Use `shm_open` to transfer the image via shared memory rather than dumping
  base64 encoded binary to the terminal.
- For the base64 path, make the loop less branchy.
- Give the project a better (unique) name.
