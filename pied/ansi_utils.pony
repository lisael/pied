use "term"

primitive MoveTo
  fun apply(line: Int, pos: Int): String =>
    ANSI.cursor(pos.u32(), line.u32())

primitive ClearLine
  fun apply(line: USize): String val =>
    recover val
      let result = String
      result.append(MoveTo(line, USize(1)))
      result.append(ANSI.erase())
      result
    end
