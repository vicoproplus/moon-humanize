#!/usr/bin/env python3
"""Generate golden-value assertions for moon-humanize tests.

This script is the equivalence gate for aligning moon-humanize (MoonBit)
against python-humanize (the sole authority, version printed below). It emits
MoonBit `assert_eq` snippets whose expected strings are the *real* outputs of
python-humanize, so the MoonBit test suite can verify byte-for-byte parity.

Usage (PowerShell):
    python scripts/gen_golden.py            # human-readable table
    python scripts/gen_golden.py --mbt      # MoonBit assert_eq snippets
    python scripts/gen_golden.py --mbt >> moonbit/src/humanize/<m>_test.mbt

The script does NOT modify any files; it only prints to stdout. The generated
`assert_eq` snippets are meant to be pasted into the appropriate `*_test.mbt`.
"""
import argparse
import datetime
import humanize

# Keep the locale English so the golden values are the canonical English output
# that moon-humanize matches when `locale_state.active == None`.
humanize.deactivate()

print(f"# python-humanize version: {humanize.__version__}")


def line(fn, args, expected):
    """Emit one human-readable golden row."""
    print(f"{fn}({args!r}) -> {expected!r}")


def mbt(test_name, fn_expr, expected):
    """Emit a MoonBit assert_eq snippet."""
    esc = expected.replace("\\", "\\\\").replace('"', '\\"')
    print(f'  @test.assert_eq({fn_expr}, "{esc}")')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--mbt", action="store_true", help="emit MoonBit assert_eq snippets")
    args = parser.parse_args()

    td = datetime.timedelta

    if args.mbt:
        print("// ---- intword (number.mbt) ----")
    for n in ["100", "999", "1000", "1234567", "999999", "10**30", "8100000000000000000000000000000000"]:
        v = eval(n) if n.startswith("10**") else n
        out = humanize.intword(v)
        if args.mbt:
            mbt(f'intword({n!r})', out)
        else:
            line("intword", n, out)

    if args.mbt:
        print("// ---- intcomma (number.mbt) ----")
    for n in [1234567.89, 100, -1000000]:
        out = humanize.intcomma(n)
        if args.mbt:
            mbt(f'intcomma({n!r})', out)
        else:
            line("intcomma", n, out)

    if args.mbt:
        print("// ---- ordinal (number.mbt) ----")
    for n in [0, 1, 2, 11, 12, 13, 112, 103, 121]:
        out = humanize.ordinal(n)
        if args.mbt:
            mbt(f'ordinal({n})', out)
        else:
            line("ordinal", n, out)

    if args.mbt:
        print("// ---- metric (number.mbt) ----")
    for n in [0, 25000, 1e14, 999]:
        out = humanize.metric(n)
        if args.mbt:
            mbt(f'metric({n!r})', out)
        else:
            line("metric", n, out)

    if args.mbt:
        print("// ---- apnumber (number.mbt) ----")
    for n in [1, 9, 10, 100]:
        out = humanize.apnumber(n)
        if args.mbt:
            mbt(f'apnumber({n})', out)
        else:
            line("apnumber", n, out)

    if args.mbt:
        print("// ---- fractional (number.mbt) ----")
    for n in [0.3, 0.5, 1.5, 3.14]:
        out = humanize.fractional(n)
        if args.mbt:
            mbt(f'fractional({n!r})', out)
        else:
            line("fractional", n, out)

    if args.mbt:
        print("// ---- naturalsize (filesize.mbt) ----")
    for v, kw in [
        (3000000, {}),
        (10**28, {}),
        (3000, {"binary": True}),
        (300, {"gnu": True}),
        (3000, {"gnu": True}),
        (300, {"format": True}),
        (-4096, {"binary": True}),
    ]:
        out = humanize.naturalsize(v, **kw)
        kws = ", ".join(f"{k}={vv!r}" for k, vv in kw.items())
        expr = f"naturalsize({v}{', ' + kws if kws else ''})"
        if args.mbt:
            mbt(expr, out)
        else:
            line("naturalsize", f"{v}, {kws}" if kws else v, out)

    if args.mbt:
        print("// ---- natural_list (lists.mbt) ----")
    # NOTE: python-humanize's natural_list accepts no style/and-or argument;
    # moon-humanize's natural_list exposes style~/cx~/ox~ as a superset. The
    # default (no args) output below is what the alignment targets.
    for items in [["a"], ["a", "b"], ["a", "b", "c"], []]:
        out = humanize.natural_list(items)
        expr = "natural_list([" + ", ".join(repr(x) for x in items) + "])"
        if args.mbt:
            mbt(expr, out)
        else:
            line("natural_list", items, out)

    if args.mbt:
        print("// ---- naturaltime (time.mbt) ----")
    for d in [td(seconds=1), td(seconds=2), td(days=1), -td(days=1), td(seconds=0)]:
        out = humanize.naturaltime(d)
        expr = f"naturaltime(TimeInput::from_delta(timedelta({d!r})))"
        if args.mbt:
            mbt(expr, out)
        else:
            line("naturaltime", d, out)

    if args.mbt:
        print("// ---- naturaldelta (time.mbt) ----")
    for d in [td(seconds=5), td(seconds=90), td(days=1, hours=2)]:
        out = humanize.naturaldelta(d)
        if args.mbt:
            mbt(f"naturaldelta(TimeInput::from_delta(timedelta({d!r})))", out)
        else:
            line("naturaldelta", d, out)

    if args.mbt:
        print("// ---- precisedelta (time.mbt) ----")
    for d in [td(days=1, hours=2), td(seconds=1.4)]:
        out = humanize.precisedelta(d)
        if args.mbt:
            mbt(f"precisedelta(TimeInput::from_delta(timedelta({d!r})))", out)
        else:
            line("precisedelta", d, out)


if __name__ == "__main__":
    main()
