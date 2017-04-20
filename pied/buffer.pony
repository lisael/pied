use "collections"

interface tag Buffer
  """
  Stores and manipulate a text
  """
  new tag empty(ed: EventDispatcher tag, name': String = "[No Name]")
  be for_lines(notifier: LineNotifier iso, start: USize, stop: USize)
  be for_line(num: USize, notifier: LineNotifier iso)
  be info(client: BufferInfoClient tag)
  be insert(lineno: USize, pos:USize, chars:Array[U8] val)
  be del(lineno: USize, pos:USize)
  be del_line(lineno: USize)
  be split_line(lineno: USize, pos: USize)
  be join(lineno: USize)

interface BufferInfoClient
  be buffer_info(bi: BufferInfo val)

interface BufferEvent is Event
  fun buffer(): Buffer

class BufferInfo
  var line_sizes: Array[USize] val
  new val create(ls: Array[USize] val) =>
    line_sizes = ls
    
class BufferSizeEvent is BufferEvent
  let data: EventData val
  let _buf: Buffer tag
  new val create(num_lines': USize, b: Buffer tag) =>
    _buf = b
    data = EventData(num_lines')
  fun name(): String => "BufferSize"
  fun apply(): EventData val => data
  fun num_lines(): USize => try data.usize() else 0 end
  fun buffer(): Buffer tag => _buf

class BufferLineChangedEvent is BufferEvent
  let lineno: USize
  let _buf: Buffer tag
  let row: Row val
  new val create(lineno': USize, r: Row val, b: Buffer tag) =>
    _buf = b
    row = r
    lineno = lineno'
  fun name(): String => "BufferLineChanged"
  fun apply(): EventData val => EventData(lineno)
  fun buffer(): Buffer tag => _buf

class BufferLineDelEvent is BufferEvent
  let lineno: USize
  let _buf: Buffer tag
  let row: Row val
  new val create(lineno': USize, r: Row val, b: Buffer tag) =>
    _buf = b
    row = r
    lineno = lineno'
  fun name(): String => "BufferLineDel"
  fun apply(): EventData val => EventData(lineno)
  fun buffer(): Buffer tag => _buf

class BufferLineNewEvent is BufferEvent
  let lineno: USize
  let _buf: Buffer tag
  let row: Row val
  new val create(lineno': USize, r: Row val, b: Buffer tag) =>
    _buf = b
    row = r
    lineno = lineno'
  fun name(): String => "BufferLineNew"
  fun apply(): EventData val => EventData(lineno)
  fun buffer(): Buffer tag => _buf

class Row
  var _content: String

  new create(s: String) =>
    _content = s

  fun ref insert(pos: USize, chars: Array[U8] val) =>
    let s = String.from_array(chars)
    _content = _content.trim(0, pos-1) + s + _content.trim(pos-1)

  fun ref insert(pos: USize, chars: String val) =>
    _content = _content.trim(0, pos-1) + chars + _content.trim(pos-1)

  fun render(out: OutStream) =>
    out.write(_content)

  fun size(): USize =>
    _content.size()

  fun ref del(pos:USize) =>
    _content = _content.trim(0, pos - 1) + _content.trim(pos)

  fun ref cut(pos: USize): String =>
    let result = _content.trim(pos - 1)
    _content = _content.trim(0, pos - 1)
    result

  fun content(): String => _content

  fun copy(): Row val =>
    recover val Row(_content) end

interface BufferAccessor
  fun ref apply(b: Buffer ref)

actor BaseBuffer is Buffer
  let _rows: Array[Row] ref
  let _name: String
  let _clients: Array[BufferNotifier tag] = Array[BufferNotifier tag]
  let _this: BaseBuffer tag
  let ev_mgr: EventDispatcher tag

  new create(ed: EventDispatcher tag, rows: Array[Row] iso, name': String = "[No Name]") =>
    _rows = consume rows
    _name = name'
    ev_mgr = ed
    _this = recover tag this end

  new empty(ed: EventDispatcher tag, name': String = "[No Name]") =>
    _rows = Array[Row]
    _rows.push(Row(""))
    _rows.push(Row("coucou"))
    _name = name'
    ev_mgr = ed
    _this = recover tag this end

  new from_stings(ed: EventDispatcher tag, strings: Array[String] val, name': String = "[No Name]") =>
    _rows = recover Array[Row] end
    for s in strings.values() do
      _rows.push(Row(s))
    end
    _name = name'
    ev_mgr = ed
    _this = recover tag this end

  be info(client: BufferInfoClient tag) =>
    let sizes = recover trn Array[USize] end
    for r in _rows.values() do
      sizes.push(r.size())
    end
    client.buffer_info(BufferInfo(consume val sizes))
 
  be register(n: BufferNotifier tag) =>
    _clients.push(n)
    n.set_buffer_size(_rows.size())
    n.set_buffer_name(_name)
    for (idx, r) in _rows.pairs() do
      n.set_buffer_line_size(idx + 1, r.size())
    end

  fun _notify_size() =>
    for c in _clients.values() do
      c.set_buffer_size(_rows.size())
    end

  fun _notify_line_size(lineno: USize) =>
    for c in _clients.values() do
      try c.set_buffer_line_size(lineno, _rows(lineno - 1).size()) end
    end

  fun _notify_del_line(lineno: USize) =>
    for c in _clients.values() do
      c.set_buffer_del_line(lineno)
    end

  be access(acc: BufferAccessor iso) =>
    let acc': BufferAccessor ref = consume acc
    acc'(this)

  be insert(lineno: USize, pos:USize, chars:Array[U8] val) =>
    try
      let row = _rows(lineno-1)
      row.insert(pos, chars)
      let copy = row.copy()
      ev_mgr.send(BufferLineChangedEvent(lineno, copy, _this))
    end

  be del(lineno: USize, pos:USize) =>
    try
      let row = _rows(lineno-1)
      row.del(pos)
      let copy = row.copy()
      ev_mgr.send(BufferLineChangedEvent(lineno, copy, _this))
    end

  be del_line(lineno: USize) =>
    _del_line(lineno)

  fun ref _del_line(lineno: USize) =>
      try
        let row = _rows.delete(lineno - 1)
        ev_mgr.send(BufferLineDelEvent(lineno, row.copy(), _this))
      end

  be join(lineno: USize)  =>
    try
      let row = _rows(lineno - 1)
      let next = _rows(lineno)
      row.insert(row.size() + 1, next.content())
      _del_line(lineno + 1)
      ev_mgr.send(BufferLineChangedEvent(lineno, row.copy(), _this))
    end

  be split_line(lineno: USize, pos: USize) =>
    try
      let row = _rows(lineno - 1)
      let remain = _rows(lineno - 1).cut(pos)
      let new_row = Row(remain)
      _rows.insert(lineno, new_row)
      ev_mgr.send(BufferLineChangedEvent(lineno - 1, row.copy(), _this))
      ev_mgr.send(BufferLineNewEvent(lineno, new_row.copy(), _this))
    end

  be for_lines(notifier: LineNotifier iso, start: USize=0, stop: USize=0) =>
    let n: LineNotifier ref = consume notifier
    for r in _rows.values() do
      n(r)
    end

  be for_line(num: USize, notifier: LineNotifier iso) =>
    let n: LineNotifier ref = consume notifier
    try n(_rows(num - 1)) end

  fun size(): USize => _rows.size()

  fun line_size(lineno: USize): USize ? => _rows(lineno).size()

interface LineNotifier
  fun ref apply(r: Row)

interface BufferNotifier
  be set_buffer_size(s: USize) => None
  be set_buffer_line_size(lineno: USize, size: USize) => None
  be set_buffer_del_line(lineno: USize) => None
  be set_buffer_name(n: String) => None

interface EditorOutput
  be redraw()
  be echo_error(msg: String) => None
  be echo_debug() => None
  // be register_hl(hl: Highlighter iso)
  fun ref buffer_size(): USize
