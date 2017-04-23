use "collections"
use "term"

interface Adornment
  fun name(): String
  fun start(): String
  fun stop(): String

primitive RedAdorn is Adornment
  fun name(): String => "red"
  fun start(): String => ANSI.red()
  fun stop(): String => ANSI.reset()

class Face
  let start: USize
  let stop:  USize
  let adornments: Array[Adornment val] val

  new val create(start': USize, stop': USize, adornments': Array[Adornment val] val) =>
    start = start'
    stop = stop'
    adornments = adornments'

  fun adorn_start(): String =>
    let s = recover trn String end
    for a in adornments.values() do
      s.append(a.start())
    end
    consume s

  fun adorn_stop(): String =>
    let s = recover trn String end
    for a in adornments.values() do
      s.append(a.stop())
    end
    consume s

class TermRow
  let lineno: USize
  let content: String
  let size: USize
  var prefix: String = ""
  var prefix_size: USize
  let _faces: Array[Face val]

  new iso create(lineno': USize,
                 content': String,
                 size': USize,
                 prefix': String="",
                 psize: USize=0,
                 faces: Array[Face val] iso=recover iso Array[Face val] end) =>
    content = content'
    size = size'
    lineno = lineno'
    prefix = prefix'
    prefix_size = psize
    _faces = consume faces

  fun copy(): TermRow iso^ =>
    let faces : Array[Face val] iso = recover iso Array[Face val] end
    for f in _faces.values() do
      faces.push(f)
    end
    TermRow(lineno, content, size, prefix, prefix_size, consume faces)

  fun ref adorn(start: USize, stop: USize, a: Adornment val) =>
    let aa: Array[Adornment val] trn = recover trn Array[Adornment val] end
    aa.push(a)
    _faces.push(Face(start, stop, consume aa))

  fun render(): String =>
    let line_size = content.size()
    let result = recover trn String(prefix_size + line_size) end
    result.append(ANSI.reset() + prefix)
    for i in Range(0, line_size + 1) do
      for f in _faces.values() do
        if f.stop == i then
          result.append(f.adorn_stop())
        end
      end
      for f in _faces.values() do
        if f.start == i then
          result.append(f.adorn_start())
        end
      end
      try result.push(content(i)) end
    end
    result.append(ANSI.reset())
    //result.append("aa" + _faces.size().string())
    consume result

interface TermHighlighter
  fun ref highlight(row:TermRow iso): TermRow iso^

  be highlight_row(win: TermWindow tag, row: TermRow iso, remains: Array[TermHighlighter tag] val) =>
    let row' = highlight(consume row)
    let row'' = row'.copy()
    win.render_row(consume row'')
    try
      let next = remains(0)
      let rem = remains.trim(1)
      next.highlight_row(win, consume row', rem)
    end

actor RedHighlighter is TermHighlighter
  fun ref highlight(row:TermRow iso): TermRow iso^ =>
    row.adorn(0, row.content.size(), RedAdorn)
    consume row

actor LineNumberHighlighter is TermHighlighter
  let buffer: Buffer tag
  let win: TermWindow tag
  let emgr: EventDispatcher tag
  var buf_size: USize = 0

  new create(w: TermWindow tag, b: Buffer tag, ed: EventDispatcher tag) =>
    buffer = b
    win = w
    emgr = ed
    ed.register_client(this, recover val [
        "BufferSize"
        "BufferLineDel"
        "BufferLineNew"
      ] end)
    b.info(this)

  // Plumbing //
  be buffer_info(bi: BufferInfo val) =>
    buf_size = bi.line_sizes.size()

  be recieve_event(e: Event val) =>
    match e
    | let bs: BufferSizeEvent val => if bs.buffer() is buffer then buf_size = bs.num_lines() end
    | let bld: BufferLineDelEvent val =>
      if bld.buffer() is buffer then
        buf_size = buf_size - 1
      end
    | let bln: BufferLineNewEvent val =>
      if bln.buffer() is buffer then
        buf_size = buf_size + 1
      end
    end

  fun ref highlight(row: TermRow iso): TermRow iso^ =>
    let num = recover box row.lineno.string() end
    var fill = ""
    for i in Range(0, buf_size.string().size() - num.size()) do
      fill = fill + " "
    end
    row.prefix = fill + num + "│"
    row.prefix_size = buf_size.string().size() + 1
    consume row

actor TermRenderer
  var hls: Array[TermHighlighter tag] val = recover val Array[TermHighlighter tag] end
  let win: TermWindow

  new create(w: TermWindow) =>
    win = w

  be register_highlighter(hl: TermHighlighter tag) =>
    let hls' = recover trn Array[TermHighlighter tag] end
    hls'.append(hls)
    hls'.push(hl)
    hls = consume hls'

  be render(r: TermRow iso) =>
    try
      let next = hls(0)
      let rem = hls.trim(1)
      next.highlight_row(win, consume r, rem)
    end
