"""
test_pied.pony

Test pied stuff.
"""

use "ponytest"
use "pied"

actor Main is TestList
  new create(env: Env) =>
    PonyTest(env, this)

  new make() =>
    None

  fun tag tests(test: PonyTest) =>
    test(_TestPosToByte)

class iso _TestPosToByte is UnitTest

  fun name():String => "PosToByte"

  fun apply(h: TestHelper) =>
    // h.assert_eq[USize](PosToByte("", 0), 0)
    // h.assert_eq[USize](PosToByte("", 1), 0)
    // h.assert_eq[USize](PosToByte("1", 0), 0)
    // h.assert_eq[USize](PosToByte("1", 1), 1)
    // h.assert_eq[USize](PosToByte("1è", 1), 1)
    // h.assert_eq[USize]("1è".size(), 3)
    h.assert_eq[USize](PosToByte("1è", 2), 3)
    // h.assert_eq[USize](PosToByte("", 0), 0)
    // h.assert_eq[USize](PosToByte("", 0), 0)


