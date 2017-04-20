class TermViEditMode is InputMode
  let win: TermWindow tag
  let input: TermInput tag

  new iso create(input': TermInput tag, w: TermWindow tag) =>
    win = w
    input = input'

  fun name(): String => "normal"

  fun ref apply(data: U8) =>
    match data
    // | 0x04 => input.quit() // ctrl-d
    // | 0x0E => down(false, false, false) // ctrl-n
    // | 0x10 => up(false, false, false) // ctrl-p
    // | 0x06 => right(false, false, false) // ctrl-f
    // | 0x05 => end_key(false, false, false) // ctrl-e
    | 0x08 => backspace() // ctrl-h
    | 0x0A => ret() // LF
    | 0x0D => ret() // CR
    | 0x1B => input.switch_mode_normal() // esc
    | if data < 0x20 => None // unknown control character
    | 0x7F => backspace() // backspace
    else
      // Insert.
      let inp: Array[U8] val = recover val [data] end
      win.insert(inp)
    end

  // move
  fun ref up(ctrl: Bool, alt: Bool, shift: Bool) => win.up()
  fun ref down(ctrl: Bool, alt: Bool, shift: Bool) => win.down()
  fun ref left(ctrl: Bool, alt: Bool, shift: Bool) => win.left()
  fun ref right(ctrl: Bool, alt: Bool, shift: Bool) => win.right()
  fun ref home(ctrl: Bool, alt: Bool, shift: Bool) => win.home()
  fun ref end_key(ctrl: Bool, alt: Bool, shift: Bool) => win.end_of_line()

  // edit
  fun ref backspace() => win.backspace()
  fun ref delete(ctrl: Bool, alt: Bool, shift: Bool) => win.delete()
  fun ref ret() => win.split_line()

  // not implemented
  fun ref insert(ctrl: Bool, alt: Bool, shift: Bool) => None
  fun ref page_up(ctrl: Bool, alt: Bool, shift: Bool) => None
  fun ref page_down(ctrl: Bool, alt: Bool, shift: Bool) => None
  fun ref fn_key(i: U8, ctrl: Bool, alt: Bool, shift: Bool) => None
  fun ref closed() => None
