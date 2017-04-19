"""
pied/main.pony

"""

actor Main
  new create(env: Env) =>
    let s = LocalServer
    let c = TermClient(s, env)
    s.register_client(c)
    s.get_empty_buffer(c)
