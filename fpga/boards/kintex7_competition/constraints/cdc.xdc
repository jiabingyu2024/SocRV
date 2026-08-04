# The design has a single functional clock domain. Reset is asynchronously
# asserted and synchronously released by an ASYNC_REG-marked two-flop chain.
# No broad CDC or timing exception is intentionally applied here.
