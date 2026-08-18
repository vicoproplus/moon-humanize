#!/usr/bin/env python3
"""Generate golden-value assertions for moon-humanize tests.

This script is the equivalence gate for aligning moon-humanize (MoonBit)
against python-humanize (the sole authority; its version is printed below).
Each MoonBit `assert_eq` snippet's expected string is the *real* output of the
installed python-humanize, so the MoonBit test suite verifies byte-for-byte
parity.

Usage (PowerShell):
    python scripts/gen_golden.py            # human-readable table
    python scripts/gen_golden.py --mbt      # MoonBit assert_eq snippets

The script does NOT modify any files; it only prints to stdout. `--mbt` output
is valid MoonBit and is meant to be pasted into the "python parity" test
sections of the corresponding `*_test.mbt`.

Notes on MoonBit signatures:
- intcomma / ordinal / apnumber / fractional / intword take a String argument.
- naturalsize takes a Double, so integer python inputs get a trailing ".0".
- natural_list takes ArrayView[String]; empty input is written `natural_list([])`.
- naturaltime / naturaldelta / precisedelta goldens are hand-verified in
  time_test.mbt (their MoonBit inputs use TimeInput::from_delta/from_seconds),
  so this script only prints them in human-readable mode.
"""
import argparse
import datetime
import humanize

# Canonical English output — what moon-humanize matches when no locale is active.
humanize.deactivate()

MBT = False
VERSION = humanize.__version__


def line(label, expr, expected):
    print(f"{label}({expr}) -> {expected!r}")


def mbt(expr, expected):
    esc = expected.replace("\\", "\\\\").replace('"', '\\"')
    print(f'  @test.assert_eq({expr}, "{esc}")')


def probe(label, expr, call):
    """Evaluate python `call`, emit one golden row (or MoonBit assert)."""
    out = call()
    if MBT:
        mbt(expr, out)
    else:
        line(label, expr, out)


def main():
    global MBT
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--mbt", action="store_true",
                        help="emit MoonBit assert_eq snippets")
    args = parser.parse_args()
    MBT = args.mbt

    td = datetime.timedelta
    sec = "// %s"

    print(f"# python-humanize version: {VERSION}")
    if MBT:
        print(sec % "intword (number.mbt)")
    for v in [
        "100",
        "999",
        "1000",
        "1234567",
        "999999",
        # 1e30 -> "1.0 nonillion"; 8.1e33 -> "8.1 decillion"
        "1000000000000000000000000000000",
        "8100000000000000000000000000000000",
    ]:
        probe("intword", f'intword("{v}")', lambda v=v: humanize.intword(v))

    if MBT:
        print(sec % "intcomma (number.mbt)")
    for v in ["1234567.89", "100", "-1000000"]:
        probe("intcomma", f'intcomma("{v}")', lambda v=v: humanize.intcomma(v))

    if MBT:
        print(sec % "ordinal (number.mbt)")
    for v in ["0", "1", "2", "11", "12", "13", "112", "103", "121"]:
        probe("ordinal", f'ordinal("{v}")', lambda v=v: humanize.ordinal(v))

    if MBT:
        print(sec % "metric (number.mbt)")
    for v in [0.0, 25000.0, 1e14, 999.0]:
        probe("metric", f"metric({v})", lambda v=v: humanize.metric(v))

    if MBT:
        print(sec % "apnumber (number.mbt)")
    for v in ["1", "9", "10", "100"]:
        probe("apnumber", f'apnumber("{v}")', lambda v=v: humanize.apnumber(v))

    if MBT:
        print(sec % "fractional (number.mbt)")
    for v in ["0.3", "0.5", "1.5", "3.14"]:
        probe("fractional", f'fractional("{v}")', lambda v=v: humanize.fractional(v))

    if MBT:
        print(sec % "naturalsize (filesize.mbt)")
    for value, kw, moon_expr in [
        (3000000, {}, "naturalsize(3000000.0)"),
        (10 ** 28, {}, "naturalsize(10000000000000000000000000000.0)"),
        (3000, {"binary": True}, "naturalsize(3000.0, binary=true)"),
        (300, {"gnu": True}, "naturalsize(300.0, gnu=true)"),
        (3000, {"gnu": True}, "naturalsize(3000.0, gnu=true)"),
        (1024, {"gnu": True}, "naturalsize(1024.0, gnu=true)"),
        (1, {"gnu": True}, "naturalsize(1.0, gnu=true)"),
        # rounding push-up: 999.999 kB formats to "1000.0 kB" -> "1.0 MB"
        (999999, {}, "naturalsize(999999.0)"),
        (999999, {"gnu": True}, "naturalsize(999999.0, gnu=true)"),
        (300, {"format": "%.0f"}, 'naturalsize(300.0, format="%.0f")'),
        (-4096, {"binary": True}, "naturalsize(-4096.0, binary=true)"),
    ]:
        probe("naturalsize", moon_expr,
              lambda value=value, kw=kw: humanize.naturalsize(value, **kw))

    if MBT:
        print(sec % "natural_list (lists.mbt)")
    # python-humanize's natural_list takes no style argument; its default output
    # is what moon-humanize matches with default args (style="standard").
    for items in [["a"], ["a", "b"], ["a", "b", "c"], []]:
        inner = ", ".join(f'"{x}"' for x in items)
        expr = f"natural_list([{inner}])"
        probe("natural_list", expr,
              lambda items=items: humanize.natural_list(items))

    if MBT:
        print(sec % "time (time.mbt)")
        print("  // naturaltime/naturaldelta/precisedelta goldens are hand-verified")
        print("  // in time_test.mbt (see the 'time python parity' test).")
    else:
        for d in [td(seconds=1), td(days=1), -td(days=1)]:
            line("naturaltime", repr(d), humanize.naturaltime(d))
        for d in [td(seconds=5), td(seconds=90), td(days=1, hours=2)]:
            line("naturaldelta", repr(d), humanize.naturaldelta(d))
        for d in [td(days=1, hours=2), td(seconds=1.4)]:
            line("precisedelta", repr(d), humanize.precisedelta(d))


if __name__ == "__main__":
    main()
