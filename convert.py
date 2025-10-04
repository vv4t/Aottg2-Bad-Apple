import string
from PIL import Image
import colorsys
import json

WIDTH = 100
HEIGHT = 75

# Initial Compression Dictionary, ensure this matches with `show-video.cl`
tokens = [
  "<color=white",
  "<color=black",
  ">█",
  "</color>",
  "█",
  "\\n",
]

def main():
  res = {}
  
  with Image.open("bad_apple.gif") as img:
    # Convert only every 4th frame
    frame_count = img.n_frames // 4
    
    img.seek(1)
    try:
      frame = 0
      while True:
        resized_img = img.resize((WIDTH, HEIGHT), Image.Resampling.LANCZOS)
        data = resized_img.load()
        res[str(frame)] = "string:" + encode_frame(data)
        print("Frame:", str(frame + 1) + "/" + str(frame_count))
        frame += 1
        img.seek(img.tell() + 4)
    except EOFError:
      pass

  res["frames"] = "int:" + str(len(res.keys()))

  text = json.dumps(res)
  with open("VIDEO.txt", "w") as f:
    f.write(text)

def encode_frame(data):
  text = ""
  for i in range(HEIGHT):
    buffer = ""
    prev = None
    for j in range(WIDTH):
      R, G, B = tuple([k / 256.0 for k in data[j,i][:3]])
      alpha = 0.2989 * R + 0.5870 * G + 0.1140 * B
      code = "white" if alpha > 0.5 else "black"
      
      if code == prev:
        buffer += "█"
      else:
        if buffer:
          text += f"<color={prev}>{buffer}</color>"
        prev = code
        buffer = "█"
        
    text += f"<color={prev}>{buffer}</color>"
    text += "\\n"
  
  text = tokenize(text)
  text = compress(text)
  text = ",".join(map(str, text))
  
  return text

def compress(text):
  d = dict([ (b, a) for a, b in enumerate(tokens) ])
  
  res = []
  p = ""
  for c in text:
    pc = p + c
    if pc in d:
      p = pc
    else:
      d[pc] = len(d.keys())
      res.append(d[p])
      p = c
  
  if pc in d:
    res.append(d[p])
  
  return res

def decompress(text):
  d = [ b for a, b in enumerate(tokens) ]
  
  res = d[text[0]]
  p = res
  for c in text[1:]:
    if c >= len(d):
      d.append(p + "," + p.split(",")[0])
      res += d[c].replace(",", "")
      p = d[c]
    else:
      res += d[c].replace(",", "")
      d.append(p + "," + d[c].split(",")[0])
      p = d[c]
  
  return res

def find_token(text):
  for token in tokens:
    if text.startswith(token):
      return token
  return None

def tokenize(text):
  res = []
  while text != "":
    token = find_token(text)
    res.append(token)
    text = text[len(token):]
  return res

if __name__ == "__main__":
  main()
