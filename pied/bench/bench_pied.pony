"""
bench_pied.pony

Bench pied stuff.
"""

use "ponybench"
use "pied"

actor Main
  let bench: PonyBench
  new create(env: Env) =>
    bench = PonyBench(env)
    bench[I32]("Add", {(): I32 => I32(2) + 2}, 1000)


