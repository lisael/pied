use "collections"
use "debug"

primitive PosToByte
  fun apply(s: String, pos: USize): USize =>
    var bytes: USize = 0
    var idx: USize = 0
    let runes = s.runes()
    while idx < pos do
      Debug("idx: " + idx.string())
      let r: U32 = try runes.next() else 0 end
      if r == 0 then break end
      Debug("r: " + r.string())
      match r
      | if r > 0xFFFFFF => bytes = bytes + 4
      | if r > 0xFFFF => bytes = bytes + 3
      | if r > 0x80 => bytes = bytes + 2
      else
        bytes = bytes + 1
      end
      Debug("bytes: " + bytes.string())
      idx = idx + 1
    end
    bytes
