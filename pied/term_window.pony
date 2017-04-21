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
  var first_line: USize = 1

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
        buf_size = buf_size - 1
        _redraw()
      end
    | let bln: BufferLineNewEvent val =>
      if bln.buffer() is buffer then
        buf_size = buf_size + 1
        _redraw()
      end
    end

  // Utils //
  fun _last_row(): USize =>
    """last line as a row"""
    _line_to_row(buf_size)

  fun _last_visible_row(): USize =>
    _line_to_row(_last_visible_line())

  fun _last_visible_line(): USize =>
    """last visble line in the window"""
    var last_row = _last_row()
    if last_row > (height - 2) then
      _row_to_line(height - 2)
    else
      buf_size
    end

  fun _reset_cursor(notify: Bool=false) =>
    out.write(MoveTo(cur_row, cur_col))
    if notify then
      emgr.send(CursorMoveEvent(cur_line(), cur_pos()))
    end

  fun cur_pos(): USize => cur_col

  fun cur_line(): USize => (first_line + cur_row) - 1

  fun _line_to_row(line: USize): USize =>
    (line - first_line) + 1

  fun _row_to_line(row: USize): USize =>
    (first_line + row) - 1

  be write(data: String, reset_cursor: Bool=true) =>
    out.write(data)
    if reset_cursor then
      _reset_cursor()
    end

  fun ref _move_cursor(row: USize, col: USize, notify: Bool=false) =>
    var changed = false
    if row != 0 then
      let old_row = cur_row = row
      changed = old_row != row
    end
    if col != 0 then
      let old_col = cur_col = col
      changed = changed or (old_col != col)
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
      if (line >= first_line) and (line <= _last_visible_line()) then
        out.write(ClearLine(_line_to_row(line)))
        // out.write(line.string() + " " + first_line.string() + " " + _last_visible_line().string() + " ")
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
    buffer.for_lines(consume notifier, first_line, _last_visible_line())
    if height > 1 then
      for row in Range(_last_row(), height - 1 ) do
        out.write(ClearLine(row))
        out.write(ANSI.blue() + "~" + ANSI.reset())
      end
    end
    _reset_cursor()

  // Scroll //
  be scroll(rows: ISize) =>
    _scroll(rows)
    
  fun ref _scroll(rows: ISize) =>
    if rows > 0 then _scroll_down(rows.usize()) end
    if rows < 0 then _scroll_up((0 - rows).usize()) end

  fun ref _scroll_up(rows: USize) =>
    if first_line <= rows then
      first_line = 1
    else
      first_line = first_line - rows
    end
    _redraw()
    _reset_cursor(true)

  fun ref _scroll_down(rows: USize) =>
    let expected = first_line + rows
    first_line = expected.min(buf_size) 
    _redraw()
    _reset_cursor(true)

  // Insert //
  be insert(chars: Array[U8] val) =>
    buffer.insert(cur_line(), cur_pos(), chars)
    _move_cursor(0, cur_col + 1, true)

  be split_line() =>
    buffer.split_line(cur_line(), cur_pos())
    _down(true, true)
    _home(true)
    redraw()

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

  fun ref _down(notify: Bool=false, force: Bool=false) =>
    if (cur_line() == buf_size) and not force then
      return
    end
    var row = cur_row
    if cur_row < _last_visible_row() then
      row = row + 1
    else
      if (not force) or (cur_row == (height - 2)) then
        _scroll_down(1)
      else
        row = row + 1
      end
    end
    let col: USize = try
      let ls = line_sizes(cur_line() + 1)
      if cur_col > ls then
        ls + 1
      else
        0
      end
    else
      1
    end
    _move_cursor(row, col, notify)

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
      var row = cur_row 
      if cur_row == 1 then
        _scroll_up(1)
      else
        row = cur_row - 1
      end
      try
        let ls = line_sizes(cur_line() - 1)
        if cur_col > ls then
          col = ls + 1
        end
      end
      _move_cursor(row, col, notify)
    end

  be home() =>
    _home(true)

  fun ref _home(notify: Bool=true) =>
    _move_cursor(0, 1, notify)

  be right() =>
    _right(true)

  fun ref _right(notify: Bool=false) =>
    if try cur_col <= line_sizes(cur_line()) else false end then
      _move_cursor(0, cur_col + 1, notify)  
    end

