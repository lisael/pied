interface Server
  """
  The server provides buffers and orchestrates the clients.
  """
  be register_client(c: Client tag)
  be get_empty_buffer(c: (Client tag | None)) 


actor LocalServer is Server
  let buffers: Array[Buffer tag] = Array[Buffer tag]
  let clients: Array[Client tag] = Array[Client tag]
  let emgr: EventDispatcher tag

  new create() =>
    emgr = EventDispatcher

  be register_client(c: Client tag) =>
    clients.push(c)
    c.set_event_dispatcher(emgr)

  be get_empty_buffer(c: (Client tag | None)) =>
    let b = BaseBuffer.empty(emgr)
    buffers.push(b)
    try (c as Client tag).set_buffer(b) end
