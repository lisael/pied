use "term"
use "collections"

class CursorMoveEvent is Event
  let data: EventData val
  new val create(line: USize, col:USize) =>
    data = EventData(recover val [EventData(line); EventData(col)] end)
  fun name(): String => "CursorMove"
  fun apply(): EventData val => data
  fun cur_pos(): (USize, USize) ? => (data.array()(0).usize(), data.array()(1).usize())

actor TermWindow is Window
  """
  Window in a TermClient.
  """
  let buffer: Buffer tag
  var cur_row: USize = 1
  var cur_col: USize = 1
  var buf_size: USize = 1
  var height: USize = 0
  var width: USize = 0
  let emgr: EventDispatcher tag
  let out: OutStream
  var line_sizes: Array[USize] = Array[USize]
  let status_line: TermStatusLine tag
  let _this: TermWindow tag
  let first_line: USize = 1

  new create(b: Buffer tag, out': OutStream, ed: EventDispatcher tag) =>
    buffer = b
    out = out'
    emgr = ed
    status_line = TermStatusLine(this, emgr)
    _this = recover tag this end
    ed.register_client(this, recover val [
        "TermGeom"
        "BufferSize"
        "BufferLineChanged"
        "BufferLineDel"
        "BufferLineNew"
      ] end)
    b.info(this)

  // Plumbing //
  be buffer_info(bi: BufferInfo val) =>
    line_sizes = [0]
    line_sizes.concat(bi.line_sizes.values())
    buf_size = bi.line_sizes.size()

  be recieve_event(e: Event val) =>
    match e
    | let tg: TermGeomEvent val => try (height, width) = tg.geom(); _redraw() end
    | let bs: BufferSizeEvent val => if bs.buffer() is buffer then buf_size = bs.num_lines() end
    | let blc: BufferLineChangedEvent val =>
      if blc.buffer() is buffer then
        render_line(blc.lineno, blc.line.content(), blc.line.size())
      end
    | let bld: BufferLineDelEvent val =>
      if bld.buffer() is buffer then
        _redraw()
        buf_size = buf_size - 1
      end
    | let bln: BufferLineNewEvent val =>
      if bln.buffer() is buffer then
        _redraw()
        buf_size = buf_size + 1
      end
    end

  // Utils //
  fun _last_row(): USize =>
    """last line as a row"""
    _line_to_row(buf_size)

  fun _last_line(): USize =>
    """last visble line in the window"""
    buf_size

  fun _reset_cursor(notify: Bool=false) =>
    out.write(MoveTo(cur_row, cur_col))
    if notify then
      emgr.send(CursorMoveEvent(cur_line(), cur_pos()))
    end

  fun cur_pos(): USize => cur_col

  fun cur_line(): USize => (first_line + cur_row) - 1

  fun _line_to_row(line: USize): USize =>
    (line - first_line) + 1

  fun _row_to_line(row: USize) =>
    (first_line + row) - 1

  be write(data: String, reset_cursor: Bool=true) =>
    out.write(data)
    if reset_cursor then
      _reset_cursor()
    end

  fun ref _move_cursor(line: USize, col: USize, notify: Bool=false) =>
    var changed = false
    if line != 0 then
      let old_line = cur_row = line
      changed = old_line != line
    end
    if col != 0 then
      let old_col = cur_col = col
      changed = old_col != col
    end
    _reset_cursor(notify and changed)

  fun ref set_line_size(line: USize, size: USize) =>
    while line > line_sizes.size() do
      line_sizes.reserve(line_sizes.size() + 20)
      for _ in Range(0,20) do
        line_sizes.push(0)
      end
    end
    try line_sizes.update(line, size) end

  // Render //
  be render_line(line: USize=0, content: String="", size: USize=0) =>
    if line == 0 then
      let line' = cur_line()
      let notifier = object iso is LineNotifier
          fun ref apply(r: Line) =>
            _this.render_line(line', r.content(), r.size())
        end
      buffer.for_line(line', consume notifier)
    else
      if (line >= first_line) and (line <= _last_line()) then
        out.write(ClearLine(_line_to_row(line)))
        // out.write(line.string() + " " + first_line.string() + " " + _last_line().string() + " ")
        out.write(content)
      end
      set_line_size(line, size)
      _reset_cursor()
    end

  be redraw() =>
    _redraw()

  fun ref _redraw() =>
    let notifier = object iso is LineNotifier
        var idx: USize = first_line
        fun ref apply(r: Line) =>
          _this.render_line(idx = idx + 1, r.content(), r.size())
      end
    buffer.for_lines(consume notifier, first_line, _last_line())
    if height > 1 then
      for row in Range(_last_row(), height - 1 ) do
        out.write(ClearLine(row))
        out.write(ANSI.blue() + "~" + ANSI.reset())
      end
    end
    _reset_cursor()

  // Insert //
  be insert(chars: Array[U8] val) =>
    buffer.insert(cur_line(), cur_pos(), chars)
    _move_cursor(0, cur_col + 1, true)

  be split_line() =>
    buffer.split_line(cur_line(), cur_pos())
    _move_cursor(cur_row + 1, 1, true)

  be backspace() =>
    if cur_col == 1 then
      if cur_line() == 1 then
        return
      end
      _up()
      _end_of_line()
      buffer.join(cur_line())
    else
      _move_cursor(cur_row, cur_col - 1, true)
      _delete()
    end

  be delete() =>
    _delete()

  fun ref _delete() =>
    buffer.del(cur_line(), cur_pos())

  // Cursor moves //  
  be end_of_line() =>
    // out.write("EOL " + try (line_sizes(cur_line()) + 1).string() else "error" end)
    _end_of_line(true)

  fun ref _end_of_line(notify: Bool=false) =>
    try
      _move_cursor(0, line_sizes(cur_line()) + 1, notify)
    end

  be down() =>
    _down(true)

  fun ref _down(notify: Bool=false) =>
    if cur_row < _last_row() then
      var col: USize = 0
      let row = cur_row + 1
      try
        let ls = line_sizes(cur_line() + 1)
        if cur_col > ls then
          col = ls + 1
        end
      end
      _move_cursor(row, col, notify)
    end

  be left() =>
    _left(true)

  fun ref _left(notify: Bool=false) =>
    if cur_col > 1 then
      _move_cursor(0, cur_col - 1, notify)  
    end

  be up() =>
    _up(true)

  fun ref _up(notify: Bool=false) =>
    if cur_line() > 1 then
      var col: USize = 0
      let row = cur_row - 1
      try
        let ls = line_sizes(cur_line() - 1)
        if cur_col > ls then
          col = ls + 1
        end
      end
      _move_cursor(row, col, notify)
    end

  be home() =>
    _move_cursor(0, 1, true)

  be right() =>
    _right(true)

  fun ref _right(notify: Bool=false) =>
    if try cur_col <= line_sizes(cur_line()) else false end then
      _move_cursor(0, cur_col + 1, notify)  
    end

