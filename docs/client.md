# Client - WOW 3.3.5a
Build a pure client which supports en-US and zh-CN(optional).

## Download and re-pack a usable client
Download a pure WtoLK 3.3.5a client from this [Website](https://www.dkpminus.com/blog/wow-wotlk-3-3-5a-download-wrath-of-the-lich-king-client/) using a BT downloader.


### LLA Patch `Wow.exe`
```bash
# Patch on macOS or Linux
cd $CLIENT_DIR
python3 -c '
import struct, shutil
shutil.copy2("Wow.exe", "Wow.exe.bak")
with open("Wow.exe", "r+b") as f:
    f.seek(0x3C)
    pe_offset = struct.unpack("<I", f.read(4))[0]
    char_offset = pe_offset + 22
    f.seek(char_offset)
    chars = struct.unpack("<H", f.read(2))[0]
    if chars & 0x0020:
        print("已是 LAA (4GB) 状态，无需重复修改。")
    else:
        f.seek(char_offset)
        f.write(struct.pack("<H", chars | 0x0020))
        print("成功打上 LAA 补丁！已自动备份为 Wow.exe.bak")
'
```

### Chinese Localization
#### MPQ Editor
Download the [MPQ Editor](http://www.zezula.net/en/mpq/download.html)

#### Client Patch
Download a wow 3.3.5a zhCN client, extract the folder `Interface` from below MPQs(Merge Mode)
- locale-zhCN.MPQ
- patch-zhCN.MPQ
- patch-zhCN-2.MPQ

Then create a new MPQ `patch-Z.MPQ` with the extracted folder, put it back to the folder `$CLIENT_DIR/Data`


#### Server translations
```bash
cd $CLIENT_DIR/Interface/AddOns && git clone https://github.com/z980944038-dev/EpochCN.git
```

### AddOns
- Download addons from [Legacy WOW](https://legacy-wow.com/wotlk-addons/)
- Download ElvUI from [ElvUI-WotLK](https://github.com/ElvUI-WotLK/ElvUI)
- Download **MultiBot** from [Github Repo](https://github.com/Macx-Lio/MultiBot)

## Target environments

### Linux
Proton

### Windows
Native Support

### Mac
CrossOver