use "term"

interface Client
  """
  A Client is the user-facing part of pied.
  """
  be set_buffer(b: Buffer tag)
  be set_event_dispatcher(ed: EventDispatcher tag)

interface TermWindowConsumer
  be set_window(win: TermWindow)
  // be set_buffer(b: Buffer tag)

actor TermClient is Client
  var win: Window tag
  let server: Server tag
  let win_consumers: Array[TermWindowConsumer tag] = Array[TermWindowConsumer tag]
  let env: Env
  var has_input: Bool = false
  var ev_mgr: (EventDispatcher tag| None) = None

  new create(s: Server tag, e: Env) =>
    server = s
    win = NullWindow
    env = e

  be set_buffer(b: Buffer tag) =>
    try
      win = TermWindow(b, env.out, ev_mgr as EventDispatcher tag)
      if not has_input then
        init_input()
        has_input = true
      else
        notify_win_consumers()
      end
    else
      env.out.print("sdfdf")
    end

  be set_event_dispatcher(ed: EventDispatcher tag) =>
    ev_mgr = ed

  be register_win_consumer(c: TermWindowConsumer tag) =>
    win_consumers.push(c)
    try
      c.set_window(win as TermWindow tag)
    end

  fun ref notify_win_consumers() =>
    for c in win_consumers.values() do
      try c.set_window(win as TermWindow) end
    end

  fun ref init_input() =>
    try
      let input = TermInput(this, win as TermWindow tag, ev_mgr as EventDispatcher tag)
      env.out.write(ANSI.clear())
      
      let term = ANSITerm(recover InputNotify(input) end, env.input)

      let notify = object iso
        let term: ANSITerm = term
        fun ref apply(data: Array[U8] iso) => term(consume data)
        fun ref dispose() => term.dispose()
      end
      env.input(consume notify)
    end
