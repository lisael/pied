class TermViEditMode is InputMode
  let win: TermWindow tag
  let input: TermInput tag
  var codepoint: Array[U8] trn
  var codepoint_size: USize = 1

  new iso create(input': TermInput tag, w: TermWindow tag) =>
    win = w
    input = input'
    codepoint = recover trn Array[U8] end

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
      match data
        // Insert.
      | if (data >= 240) and (data < 248)  =>  // 11110xxx
        codepoint_size = 4
        codepoint = recover trn Array[U8](4) end
      | if (data >= 224) and (data < 240) =>  // 1110xxx
        codepoint_size = 3
        codepoint = recover trn Array[U8](3) end
      | if (data >= 192) and (data < 224) =>  // 110xxxxx
        codepoint_size = 2
        codepoint = recover trn Array[U8](2) end
      | if (data >= 128) and (data < 192) =>  // 10xxxxxx
        if codepoint_size == 1 then
          // bad utf-8 encoding, ditch the input
          return
        end
      | if data < 128 =>  // ascii
        if codepoint_size != 1 then
          // bad utf-8 encoding, ditch the input and reset the codepoint
          codepoint_size = 1
          codepoint = recover trn Array[U8](1) end
          return
        end
      end
      codepoint.push(data)
      if codepoint.size() == codepoint_size then
        let input': Array[U8] val = codepoint = recover trn Array[U8](1) end
        codepoint_size = 1
        win.insert(input')      
      end
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
