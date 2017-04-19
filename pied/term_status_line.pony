use "term"

actor TermStatusLine is EventListener
  var _buf_size: USize = 0
  var _buf_name: String = "[No file]"
  var cur_line: USize = 1
  var cur_col: USize = 1
  var height: USize = 0
  var width: USize = 0
  let win: TermWindow
  var mode: String = "normal"

  new create(w: TermWindow, ed: EventDispatcher) =>
    win = w
    ed.register_client(this, recover val ["CursorMove"; "TermGeom"; "TermMode"] end)

  be recieve_event(e: Event val) =>
    match e
    | let cm : CursorMoveEvent val => try (cur_line, cur_col) = cm.cur_pos() end
    | let tg: TermGeomEvent val => try (height, width) = tg.geom() end
    | let tm: TermModeEvent val => mode = tm.mode()
    end
    _redraw()

  be redraw() =>
    _redraw()

  fun _redraw() =>
    if (width > 0) and (height > 1) then
      let left' = _buf_name
      let length = width
      let right' = if mode != "normal" then mode + " " else "" end + height.string() + "x" + width.string() + " " +
        cur_line.string() + ":" + cur_col.string()
      let fill = String.from_array(recover val Array[U8].init(' ', length - left'.size() - right'.size()) end)
      let result = ANSI.reverse() + ClearLine(height - 1) + left' + fill + right' + ANSI.reset()
      win.write(result)
    end
