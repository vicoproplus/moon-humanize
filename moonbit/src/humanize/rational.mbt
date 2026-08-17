// Minimal rational number type, supporting the needs of `fractional` and
// (later) `precisedelta`. Mirrors Python's `fractions.Fraction`: a normalized
// numerator/denominator pair (denominator > 0, sign carried by numerator)
// with `limit_denominator` approximation.
//
// See docs/specs/port-to-moonbit.md (porting gap G4).

/// A normalized fraction `numer / denom` with `denom > 0`.
/// The sign (if any) is carried by `numer`.
pub struct Rational {
  numer : Int
  denom : Int
} derive(Show)

/// Greatest common divisor (Euclidean), always non-negative.
fn gcd(a : Int, b : Int) -> Int {
  let mut x = if a < 0 { -a } else { a }
  let mut y = if b < 0 { -b } else { b }
  while y != 0 {
    let t = y
    y = x % y
    x = t
  }
  x
}

/// Construct a normalized Rational from integer numerator/denominator.
pub fn Rational::new(numer : Int, denom : Int) -> Rational {
  if denom == 0 {
    abort("Rational: denominator is zero")
  }
  let d = gcd(numer, denom)
  if denom < 0 {
    { numer: -numer / d, denom: -denom / d }
  } else {
    { numer: numer / d, denom: denom / d }
  }
}

/// Best rational approximation of `x` with denominator <= `max_den`, using a
/// brute-force search over denominators (same result as Python's
/// `Fraction.limit_denominator` because we minimize |p/q - x| and prefer
/// smaller q on ties).
pub fn Rational::from_float_approx(x : Double, max_den : Int) -> Rational {
  if x.is_nan() || x.is_inf() {
    abort("Rational::from_float_approx: not finite")
  }
  if x == 0.0 {
    return { numer: 0, denom: 1 }
  }
  let max_q = if max_den < 1 { 1 } else { max_den }
  let neg = x < 0.0
  let ax = if neg { -x } else { x }
  let mut best_n : Int = 0
  let mut best_d : Int = 1
  let mut best_err = ax // |0/1 - x|
  for q = 1; q <= max_q; q = q + 1 {
    let p = @math.round(ax * q.to_double()).to_int()
    let approx = p.to_double() / q.to_double()
    let err = (ax - approx).abs()
    // prefer strictly smaller error; on equal error keep smaller denominator
    if err < best_err {
      best_err = err
      best_n = p
      best_d = q
    }
  }
  if neg {
    best_n = -best_n
  }
  Rational::new(best_n, best_d)
}

/// The numerator (sign carried here).
pub fn Rational::numerator(self : Rational) -> Int {
  self.numer
}

/// The denominator (always > 0).
pub fn Rational::denominator(self : Rational) -> Int {
  self.denom
}
