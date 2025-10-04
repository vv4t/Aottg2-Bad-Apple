
class Main
{
  _frameCount = 0;
  _frameData = List();
  
  function OnGameStart() {
    if (Network.IsMasterClient) {
      VideoManager.OnGameStart();
    }
    Network.SendMessage(Network.MasterClient, "download");
  }
  
  function OnPlayerJoin(player) {
    if (Network.IsMasterClient) {
      self.StartTransfer(player);
    }
  }
  
  function OnNetworkMessage(sender, message) {
    if (Network.IsMasterClient && message == "download") {
      VideoManager.StartTransfer(sender, VideoManager.GetFrameNumber());
    } elif (String.StartsWith(message, "frameCount ")) {
      frameCount = Convert.ToInt(String.Substring(message, String.Length("frameCount ")));
      self.BeginReceive(frameCount);
    } else {
      data = Json.LoadFromString(message);
      self.ReceiveChunk(data);
    }
  }
  
  function BeginReceive(frameCount) {
    for (i in Range(0, frameCount, 1)) {
      self._frameData.Add("");
    }
    VideoManager._frameCount = frameCount;
    self.Play();
  }
  
  function ReceiveChunk(data) {
    frameBegin = data.Get("frameBegin");
    chunk = data.Get("chunk");
    self.DecodeChunk(frameBegin, chunk);
  }
  
  coroutine DecodeChunk(frameBegin, chunk) {
    for (i in Range(0, chunk.Count, 1)) {
      data = chunk.Get(i);
      lzw = LZW(data);
      wait lzw.Decompress();
      self._frameData.Set(frameBegin + i, lzw.GetResult());
    }
  }
  
  coroutine Play() {
    wait 3.0;
    
    while (true) {
      data = self._frameData.Get(VideoManager.GetFrameNumber());
      displayData = "<size=6>" + data + "</size>";
      displayData += "【東方】Bad Apple!! ＰＶ【影絵】| " + self.FormatDuration(Convert.ToInt(VideoManager.GetSongTime())) + String.Newline;
      UI.SetLabel("TopCenter", displayData);
      wait 0.1;
    }
  }
  
  function FormatDuration(timeSeconds) {
    minutes = self.FormatZeroPad(timeSeconds / 60, 2);
    seconds = self.FormatZeroPad(Math.Mod(timeSeconds, 60), 2);
    return minutes + ":" + seconds;
  }
  
  function FormatZeroPad(num, zeroCount) {
    digitForm = Convert.ToString(num);
    
    for (i in Range(0, zeroCount - String.Length(digitForm), 1)) {
      digitForm = "0" + digitForm;
    }
    
    return digitForm;
  }
}

extension VideoManager {
  # The video length in seconds
  _videoDuration = 219;
  
  _frameCount = 0;
  _chunkData = List();
  
  function OnGameStart() {
    self.ChunkData();
  }
  
  function ChunkData() {
    PersistentData.LoadFromFile("VIDEO", false);
    self._frameCount = PersistentData.GetProperty("frames", 0);
    
    buffer = List();
    approxBufferSize = 0;
    
    for (i in Range(0, self._frameCount, 1)) {
      data = PersistentData.GetProperty(Convert.ToString(i), "");
      
      if (approxBufferSize + String.Length(data) > 24000) {
        self._chunkData.Add(buffer);
        approxBufferSize = 0;
        buffer = List();
      }
      
      approxBufferSize += String.Length(data);
      buffer.Add(data);
    }
    
    if (buffer.Count > 0) {
      self._chunkData.Add(buffer);
    }
    
    PersistentData.Clear();
  }
  
  function StartTransfer(player, frameNumber) {
    chunkHead = 0;
    frameBegin = 0;
    
    for (chunk in self._chunkData) {
      if (frameBegin + chunk.Count >= frameNumber) {
        break;
      }
      frameBegin += chunk.Count;
      chunkHead += 1;
    }
    
    Network.SendMessage(player, "frameCount " + Convert.ToString(self._frameCount));
    self.TransferChunks(player, frameBegin, chunkHead);
  }
  
  coroutine TransferChunks(player, frameBegin, chunkHead) {
    wait 1.0;
    
    i = chunkHead;
    
    chunk = self._chunkData.Get(i);
    self.SendChunk(player, frameBegin, chunk);
    wait 0.5;
    
    frameBegin = Math.Mod(frameBegin + self._chunkData.Get(i).Count, self._frameCount);
    i = Math.Mod(i + 1, self._chunkData.Count);
    
    while (i != chunkHead && self.IsPlayerConnected(player.ID)) {
      chunk = self._chunkData.Get(i);
      self.SendChunk(player, frameBegin, chunk);
      wait 0.5;
      
      frameBegin = Math.Mod(frameBegin + self._chunkData.Get(i).Count, self._frameCount);
      i = Math.Mod(i + 1, self._chunkData.Count);
    }
  }
  
  function SendChunk(player, frameBegin, chunk) {
      data = Dict();
      data.Set("chunk", chunk);
      data.Set("frameBegin", frameBegin);
      data = Json.SaveToString(data);
      Network.SendMessage(player, data);
  }
  
  function IsPlayerConnected(id) {
    for (player in Network.Players) {
      if (player.ID == id) {
        return true;
      }
    }
    return false;
  }
  
  function GetSongTime() {
    songTime = Time.GameTime - Math.Floor(Time.GameTime / self._videoDuration) * self._videoDuration;
    return songTime;
  }
  
  function GetFrameNumber() {
    songTime = self.GetSongTime();
    frameNumber = Convert.ToInt(songTime / self._videoDuration * self._frameCount);
    return frameNumber;
  }
}

# Basic compression
class LZW {
  function Init(data) {
    # Initial Compression Dictionary, ensure this matches with `convert.py`
    self._dict = List();
    self._dict.Add("<color=white");
    self._dict.Add("<color=black");
    self._dict.Add(">█");
    self._dict.Add("</color>");
    self._dict.Add("█");
    self._dict.Add(String.Newline);
    
    self._data = String.Split(data, ",");
    self._res = self._dict.Get(Convert.ToInt(self._data.Get(0)));
    self._p = self._res;
  }
  
  function GetResult() {
    return self._res;
  }
  
  function Decompress() {
    for (i in Range(1, self._data.Count, 1)) {
      c = Convert.ToInt(self._data.Get(i));
      if (c >= self._dict.Count) {
        firstEntry = self.GetFirstEntry(self._p);
        newEntry = self._p + "," + firstEntry;
        self._dict.Add(newEntry);
        self._p = newEntry;
        self._res += String.Replace(newEntry, ",", "");
      } else {
        entry = self._dict.Get(c);
        firstEntry = self.GetFirstEntry(entry);
        self._dict.Add(self._p + "," + firstEntry);
        self._p = entry;
        self._res += String.Replace(entry, ",", "");
      }
    }
  }
  
  function GetFirstEntry(text) {
    commaIndex = String.IndexOf(text, ",");
    if (commaIndex > 0) {
      return String.SubstringWithLength(text, 0, commaIndex);
    } else {
      return text;
    }
  }
}
