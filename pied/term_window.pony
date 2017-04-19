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
  var cur_line: USize = 1
  var cur_col: USize = 1
  var buf_size: USize = 1
  var height: USize = 0
  var width: USize = 0
  let emgr: EventDispatcher tag
  let out: OutStream
  var line_sizes: Array[USize] = Array[USize]
  let status_line: TermStatusLine tag
  let _this: TermWindow tag

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
        render_line(blc.lineno, blc.row.content(), blc.row.size())
      end
    | let bld: BufferLineDelEvent val =>
      if bld.buffer() is buffer then
        _redraw()
      end
    end

  // Utils //
  fun _last_term_lineno(): USize =>
    buf_size

  fun _reset_cursor() =>
    out.write(MoveTo(cur_line, cur_col))

  be write(data: String, reset_cursor: Bool=true) =>
    out.write(data)
    if reset_cursor then
      _reset_cursor()
    end

  fun ref _move_cursor(line: USize, col: USize, notify: Bool=false) =>
    var changed = false
    if line != 0 then
      let old_line = cur_line = line
      changed = old_line != line
    end
    if col != 0 then
      let old_col = cur_col = col
      changed = old_col != col
    end
    _reset_cursor()
    if notify and changed then
      emgr.send(CursorMoveEvent(cur_line, cur_col))
    end

  // Render //
  be render_line(lnum: USize=0, content: String="", size: USize=0) =>
    if lnum == 0 then
      let notifier = object iso is LineNotifier
          fun ref apply(r: Row) =>
            _this.render_line(cur_line, r.content(), r.size())
        end
      buffer.for_line(cur_line, consume notifier)
    else
      out.write(ClearLine(lnum))
      out.write(content)
      try line_sizes.update(lnum, size) end
      _reset_cursor()
    end

  be redraw() =>
    _redraw()

  fun ref _redraw() =>
    let notifier = object iso is LineNotifier
        var idx: USize=1
        fun ref apply(r: Row) =>
          _this.render_line(idx = idx + 1, r.content(), r.size())
      end
    buffer.for_lines(consume notifier)
    if height > 1 then
      for lineno in Range(_last_term_lineno(), height - 1 ) do
        out.write(ClearLine(lineno))
        out.write(ANSI.blue() + "~" + ANSI.reset())
      end
    end
    _reset_cursor()
    emgr.send(CursorMoveEvent(cur_line, cur_col))

  // Insert //
  be insert(chars: Array[U8] val) =>
    buffer.insert(cur_line, cur_col, chars)
    _move_cursor(cur_line, cur_col + 1, true)

  be backspace() =>
    if cur_col == 1 then
      if cur_line == 1 then
        return
      end
      _up()
      _end_of_line()
      buffer.join(cur_line)
      // _clear()
      // redraw()
      return
    end
    _move_cursor(cur_line, cur_col - 1, true)
    _delete()

  be delete() =>
    _delete()

  fun ref _delete() =>
    buffer.del(cur_line, cur_col)
    // render_line()
    // _render_status()

  // Cursor moves //  
  be end_of_line() =>
    _end_of_line(true)

  fun ref _end_of_line(notify: Bool=false) =>
    try
      _move_cursor(0, line_sizes(cur_line) + 1, notify)
    end

  be down() =>
    _down(true)

  fun ref _down(notify: Bool=false) =>
    if cur_line < buf_size then
      var line: USize = 0
      var col: USize = 0
      line = cur_line + 1
      try
        let ls = line_sizes(line)
        if cur_col > ls then
          col = ls + 1
        end
      end
      _move_cursor(line, col, notify)
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
    if cur_line > 1 then
      var line: USize = 0
      var col: USize = 0
      line = cur_line - 1
      try
        let ls = line_sizes(line)
        if cur_col > ls then
          col = ls + 1
        end
      end
      _move_cursor(line, col, notify)
    end

  be home() =>
    _move_cursor(0, 1, true)

  be right() =>
    _right(true)

  fun ref _right(notify: Bool=false) =>
    if try cur_col <= line_sizes(cur_line) else false end then
      _move_cursor(0, cur_col + 1, notify)  
    end

