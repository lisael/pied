use "collections"

type EventDataType is (Bool|String|USize|ISize|F64|Array[EventData val] val)

class EventData
  var _data: EventDataType val

  new val create(data: EventDataType) =>
    _data = data

  fun bool(): Bool ? => _data as Bool
  fun string(): String ? => _data as String
  fun usize(): USize ? => _data as USize
  fun isize(): ISize ? => _data as ISize
  fun f64(): F64 ? => _data as F64
  fun array(): Array[EventData val] val ? => _data as Array[EventData val] val

interface EventListener
  be recieve_event(e: Event val)

interface Event
  fun name(): String
  fun apply(): EventData val

actor EventDispatcher
  let routing: Map[String, Array[EventListener tag]] = Map[String, Array[EventListener tag]]

  be register_client(c: EventListener tag, events: Array[String] val) =>
    for name in events.values() do
      let clients = try routing(name) else Array[EventListener tag] end
      clients.push(c)
      routing.update(name, clients)
    end

  be send(e: Event val) =>
    let clients = try routing(e.name()) else Array[EventListener tag] end
    for c in clients.values() do
      c.recieve_event(e)
    end
