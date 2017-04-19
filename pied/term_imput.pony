use "term"

class TermGeomEvent is Event
  let data: EventData val

  new val create(rows: USize, cols:USize) =>
    data = EventData(recover val [EventData(rows); EventData(cols)] end)
  fun name(): String => "TermGeom"
  fun apply(): EventData val => data
  fun geom(): (USize, USize) ? => (data.array()(0).usize(), data.array()(1).usize())

class TermModeEvent is Event
  let data: EventData val

  new val create(mode': String) =>
    data = EventData(mode')
  fun name(): String => "TermMode"
  fun apply(): EventData val => data
  fun mode(): String => try data.string() else "" end


interface InputMode
  fun ref apply(data: U8) => None
  fun ref up(ctrl: Bool, alt: Bool, shift: Bool) => None
  fun ref down(ctrl: Bool, alt: Bool, shift: Bool) => None
  fun ref left(ctrl: Bool, alt: Bool, shift: Bool) => None
  fun ref right(ctrl: Bool, alt: Bool, shift: Bool) => None
  fun ref delete(ctrl: Bool, alt: Bool, shift: Bool) => None
  fun ref insert(ctrl: Bool, alt: Bool, shift: Bool) => None
  fun ref home(ctrl: Bool, alt: Bool, shift: Bool) => None
  fun ref end_key(ctrl: Bool, alt: Bool, shift: Bool) => None
  fun ref page_up(ctrl: Bool, alt: Bool, shift: Bool) => None
  fun ref page_down(ctrl: Bool, alt: Bool, shift: Bool) => None
  fun ref fn_key(i: U8, ctrl: Bool, alt: Bool, shift: Bool) => None
  fun ref size(rows: U16, cols: U16) => None
  fun ref closed() => None

actor TermInput is TermWindowConsumer
  """
  Recieves inputs from the terminal and dispatch them to the current InputMode
  """
  var mode: InputMode ref
  var client: TermClient tag
  var win: TermWindow tag
  var ev_mgr: EventDispatcher tag

  new create(c: TermClient tag, w: TermWindow tag, ed: EventDispatcher tag) =>
    client = c
    win = w
    mode = TermViNormalMode(this, w)
    ev_mgr = ed

  be switch_mode_normal() =>
    mode = TermViNormalMode(this, win)
    ev_mgr.send(TermModeEvent("normal"))

  be switch_mode_edit() =>
    mode = TermViEditMode(this, win)
    ev_mgr.send(TermModeEvent("insert"))

  be set_window(w: TermWindow tag) =>
    win = w

  be apply(data: U8) => mode(data)
  be up(ctrl: Bool, alt: Bool, shift: Bool) => mode.up(ctrl, alt, shift)
  be down(ctrl: Bool, alt: Bool, shift: Bool) => mode.down(ctrl, alt, shift)
  be left(ctrl: Bool, alt: Bool, shift: Bool) => mode.left(ctrl, alt, shift)
  be right(ctrl: Bool, alt: Bool, shift: Bool) => mode.right(ctrl, alt, shift)
  be delete(ctrl: Bool, alt: Bool, shift: Bool) => mode.delete(ctrl, alt, shift)
  be insert(ctrl: Bool, alt: Bool, shift: Bool) => mode.insert(ctrl, alt, shift)
  be home(ctrl: Bool, alt: Bool, shift: Bool) => mode.home(ctrl, alt, shift)
  be end_key(ctrl: Bool, alt: Bool, shift: Bool) => mode.end_key(ctrl, alt, shift)
  be page_up(ctrl: Bool, alt: Bool, shift: Bool) => mode.page_up(ctrl, alt, shift)
  be page_down(ctrl: Bool, alt: Bool, shift: Bool) => mode.page_down(ctrl, alt, shift)
  be fn_key(i: U8, ctrl: Bool, alt: Bool, shift: Bool) => mode.fn_key(i, ctrl, alt, shift)
  be size(rows: U16, cols: U16) =>
    ev_mgr.send(TermGeomEvent(rows.usize(), cols.usize()))
    mode.size(rows, cols)
  be closed() => mode.closed()

class InputNotify is ANSINotify
  var input: TermInput tag

  new iso create(input': TermInput)=>
    input = input'

  fun ref apply(term: ANSITerm ref, data: U8) => input(data)
  fun ref up(ctrl: Bool, alt: Bool, shift: Bool) => input.up(ctrl, alt, shift)
  fun ref down(ctrl: Bool, alt: Bool, shift: Bool) => input.down(ctrl, alt, shift)
  fun ref left(ctrl: Bool, alt: Bool, shift: Bool) => input.left(ctrl, alt, shift)
  fun ref right(ctrl: Bool, alt: Bool, shift: Bool) => input.right(ctrl, alt, shift)
  fun ref delete(ctrl: Bool, alt: Bool, shift: Bool) => input.delete(ctrl, alt, shift)
  fun ref insert(ctrl: Bool, alt: Bool, shift: Bool) => input.insert(ctrl, alt, shift)
  fun ref home(ctrl: Bool, alt: Bool, shift: Bool) => input.home(ctrl, alt, shift)
  fun ref end_key(ctrl: Bool, alt: Bool, shift: Bool) => input.end_key(ctrl, alt, shift)
  fun ref page_up(ctrl: Bool, alt: Bool, shift: Bool) => input.page_up(ctrl, alt, shift)
  fun ref page_down(ctrl: Bool, alt: Bool, shift: Bool) => input.page_down(ctrl, alt, shift)
  fun ref fn_key(i: U8, ctrl: Bool, alt: Bool, shift: Bool) => input.fn_key(i, ctrl, alt, shift)
  fun ref size(rows: U16, cols: U16) => input.size(rows, cols)
  fun ref closed() => input.closed()
