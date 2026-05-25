# Stochastic CMO Monte Carlo Pricing

## Abstract

This project develops a Monte Carlo framework for pricing collateralized mortgage obligations
(CMOs) under stochastic interest rates. Interest rates are modeled using the Cox-Ingersoll-
Ross (CIR) process, and mortgage cash flows are generated from a standard amortization
structure. The analysis begins with a baseline model assuming constant prepayment, and is
then extended to incorporate stochastic prepayment and default behavior driven by interest
rate dynamics. Numerical results show that stochastic prepayment reduces CMO values by
accelerating the return of principal, while default risk has a larger negative impact due to
direct cash flow losses. Sensitivity analysis further demonstrates that interest rates, default
intensity, and mortgage rates are the primary drivers of valuation. Overall, the results
highlight the importance of modeling borrower behavior and credit risk in the valuation of
mortgage-backed securities.

## Repository Structure

```
Stochastic-CMO-Monte-Carlo-Pricing/
├── Paper/
│   └── Stochastic_CMO_Monte_Carlo_Pricing.pdf   # Full write-up
├── Julia Code/
│   └── Stochastic_CMO_Pricing_Julia_Code.ipynb  # All implementation
└── README.md
```

---

*Department of Mathematics, Florida State University — Monte Carlo Methods in Financial Mathematics, April 2026*


