"""
pied/pied.pony

Do pied stuff.
"""


actor Main
  new create(env: Env) =>
    env.out.print("Hello")

