# ---------
# CIR MODEL
# ---------

function PoissonRandN(lambda)
    if lambda<50
        u=rand()
        i=0
        p=exp(-lambda)
        F=p
        while u>F
            p=lambda*p/(i+1)
            F=F+p
            i=i+1
        end
        return i
    else
        k=floor(Int,lambda+sqrt(lambda)*randn()+0.5)
        return max(k,0)
    end
end

function nonCentralChiSqRand(k,lambda)
    m=PoissonRandN(lambda/2)
    x=0
    for i in 1:k+2*m
        x=x+randn()^2
    end
    return(x)
end

function CIRPath(rzero, alpha, b, sigma, T, n)
    h = T / n
    path = Array{Float64}(undef, n + 1)
    path[1] = rzero
    r = rzero

    c = sigma^2 * (1 - exp(-alpha * h)) / (4 * alpha)
    k = 4 * alpha * b / sigma^2

    for i in 1:n
        lambda = 4 * alpha * exp(-alpha * h) * r / (sigma^2 * (1 - exp(-alpha * h)))
        r = c * nonCentralChiSqRand(k, lambda)
        path[i + 1] = r
    end

    return path
end

# --------------
# BASE CMO MODEL
# --------------

function CMOprice(m, L, D, prepayRate, rzero, alpha, b, sigma, N)
    monthly_payment = L * m / (1 - (1 + m)^(-D))

    total_price = 0.0
    total_life_months = 0.0

    for i in 1:N
        balance = L

        # Simulate CIR rates and convert to monthly rates
        rates = CIRPath(rzero, alpha, b, sigma, D / 12, D)
        rates = rates / 12

        path_pv = 0.0
        discount_factor = 1.0
        months_used = 0

        for n in 1:D
            if balance <= 0
                break
            end

            # Mortgage cash flow calculations
            interest = m * balance
            principal = monthly_payment - interest
            prepayment = prepayRate * balance
            total_principal = principal + prepayment
            total_principal = min(total_principal, balance) # Prevent overpaying beyond remaining balance
            cash_flow = interest + total_principal

            # Path-wise discounting
            discount_factor = discount_factor / (1 + rates[n])
            path_pv += discount_factor * cash_flow

            # Update remaining balance
            balance -= total_principal
            months_used += 1
        end

        total_price += path_pv
        total_life_months += months_used
    end

    avg_price = total_price / N
    avg_prepay_rate = prepayRate
    avg_life_months = total_life_months / N
    avg_life_years = avg_life_months / 12

    println("CMO price estimate              = ", avg_price)
    println("Average prepayment rate/month  = ", avg_prepay_rate)
    println("Average mortgage life (months) = ", avg_life_months)
    println("Average mortgage life (years)  = ", avg_life_years)

    return (
        price = avg_price,
        avg_prepay_rate = avg_prepay_rate,
        avg_life_months = avg_life_months,
        avg_life_years = avg_life_years
    )
end

# ---------------------------
# STOCHASTIC PREPAYMENT MODEL
# ---------------------------

function CMOprice_prepay(m, L, D, prepay_a, prepay_b, rzero, alpha, b, sigma, N)
    monthly_payment = L * m / (1 - (1 + m)^(-D))

    total_price = 0.0
    total_avg_prepay_rate = 0.0
    total_life_months = 0.0

    for i in 1:N
        balance = L

        # Simulate CIR rates and convert to monthly rates
        rates = CIRPath(rzero, alpha, b, sigma, D / 12, D)
        rates = rates / 12

        path_pv = 0.0
        discount_factor = 1.0
        path_prepay_rate_sum = 0.0
        months_used = 0

        for n in 1:D
            if balance <= 0
                break
            end

            # Mortgage cash flow calculations
            interest = m * balance
            principal = monthly_payment - interest

            # Stochastic prepayment rate
            incentive = max(m - rates[n], 0.0)
            prepay_rate_n = prepay_a * exp(prepay_b * incentive)
            prepayment = prepay_rate_n * balance

            total_principal = principal + prepayment
            # Prevent overpaying beyond remaining balance
            total_principal = min(total_principal, balance)

            cash_flow = interest + total_principal

            # Path-wise discounting
            discount_factor = discount_factor / (1 + rates[n])
            path_pv += discount_factor * cash_flow

            # Update remaining balance
            balance -= total_principal
            
            path_prepay_rate_sum += prepay_rate_n
            months_used += 1
        end

        total_price += path_pv
        total_avg_prepay_rate += path_prepay_rate_sum / months_used
        total_life_months += months_used
    end

    avg_price = total_price / N
    avg_prepay_rate = total_avg_prepay_rate / N
    avg_life_months = total_life_months / N
    avg_life_years = avg_life_months / 12

    println("CMO price estimate              = ", avg_price)
    println("Average prepayment rate/month  = ", avg_prepay_rate)
    println("Average mortgage life (months) = ", avg_life_months)
    println("Average mortgage life (years)  = ", avg_life_years)

    return (
        price = avg_price,
        avg_prepay_rate = avg_prepay_rate,
        avg_life_months = avg_life_months,
        avg_life_years = avg_life_years
    )
end

# --------------------------------------------------
# STOCHASTIC PREPAYMENT AND STOCHASTIC DEFAULT MODEL
# --------------------------------------------------

function CMOprice_prepay_default(m, L, D, prepay_a, prepay_b, default_a, default_b, rzero, alpha, b, sigma, N)
    monthly_payment = L * m / (1 - (1 + m)^(-D))

    total_price = 0.0
    total_avg_prepay_rate = 0.0
    total_avg_default_rate = 0.0
    total_life_months = 0.0

    for i in 1:N
        balance = L

        # Simulate CIR rates and convert to monthly rates
        rates = CIRPath(rzero, alpha, b, sigma, D / 12, D)
        rates = rates / 12

        path_pv = 0.0
        discount_factor = 1.0
        path_prepay_rate_sum = 0.0
        path_default_rate_sum = 0.0
        months_used = 0

        for n in 1:D
            if balance <= 0
                break
            end

            # Mortgage cash flow calculations
            interest = m * balance
            principal = monthly_payment - interest

            # Stochastic prepayment rate
            prepay_incentive = max(m - rates[n], 0.0)
            prepay_rate_n = prepay_a * exp(prepay_b * prepay_incentive)
            prepayment = prepay_rate_n * balance

            # Stochastic default rate
            default_incentive = max(rates[n] - m, 0.0)
            default_rate_n = default_a * exp(default_b * default_incentive)
            default = default_rate_n * balance

            total_principal_reduction = principal + prepayment + default

            # Prevent overpaying/defaulting beyond remaining balance
            if total_principal_reduction > balance
                scale = balance / total_principal_reduction
                principal *= scale
                prepayment *= scale
                default *= scale
                total_principal_reduction = balance
            end

            cash_flow = interest + principal + prepayment

            # Path-wise discounting
            discount_factor = discount_factor / (1 + rates[n])
            path_pv += discount_factor * cash_flow

            # Update remaining balance
            balance -= total_principal_reduction

            path_prepay_rate_sum += prepay_rate_n
            path_default_rate_sum += default_rate_n
            months_used += 1
        end

        total_price += path_pv
        total_avg_prepay_rate += path_prepay_rate_sum / months_used
        total_avg_default_rate += path_default_rate_sum / months_used
        total_life_months += months_used
    end

    avg_price = total_price / N
    avg_prepay_rate = total_avg_prepay_rate / N
    avg_default_rate = total_avg_default_rate / N
    avg_life_months = total_life_months / N
    avg_life_years = avg_life_months / 12

    println("CMO price estimate              = ", avg_price)
    println("Average prepayment rate/month  = ", avg_prepay_rate)
    println("Average default rate/month     = ", avg_default_rate)
    println("Average mortgage life (months) = ", avg_life_months)
    println("Average mortgage life (years)  = ", avg_life_years)

    return (
        price = avg_price,
        avg_prepay_rate = avg_prepay_rate,
        avg_default_rate = avg_default_rate,
        avg_life_months = avg_life_months,
        avg_life_years = avg_life_years
    )
end

# -------
# TESTING
# -------

# Base model

CMOprice(0.065/12, 10_000_000, 360,     # Mortgage parameters
         0.002,                         # Constant prepayment parameter
         0.045, 0.3, 0.05, 0.03, 10000) # CIR parameters / N

# Stochastic prepayment model - low prepayment sensitivity

CMOprice_prepay(0.065/12, 10_000_000, 360,     # Mortgage parameters
                0.002, 40.0,                   # Prepayment parameters
                0.045, 0.3, 0.05, 0.03, 10000) # CIR parameters / N

# Stochastic prepayment model - moderate prepayment sensitivity

CMOprice_prepay(0.065/12, 10_000_000, 360,     # Mortgage parameters
                0.002, 80.0,                   # Prepayment parameters
                0.045, 0.3, 0.05, 0.03, 10000) # CIR parameters / N

# Stochastic prepayment model - high prepayment sensitivity

CMOprice_prepay(0.065/12, 10_000_000, 360,     # Mortgage parameters
                0.002, 150.0,                  # Prepayment parameters
                0.045, 0.3, 0.05, 0.03, 10000) # CIR parameters / N

# Stochastic prepayment model - higher baseline prepayment

CMOprice_prepay(0.065/12, 10_000_000, 360,     # Mortgage parameters
                0.004, 80.0,                   # Prepayment parameters
                0.045, 0.3, 0.05, 0.03, 10000) # CIR parameters / N

# Stochastic prepayment and default model - moderate prepayment sensitivity, moderate default sensitivity

CMOprice_prepay_default(0.065/12, 10_000_000, 360,    # Mortgage parameters
                       0.002, 80.0,                   # Prepayment parameters
                       0.0005, 100.0,                 # Default parameters
                       0.045, 0.3, 0.05, 0.03, 10000) # CIR parameters / N

# Stochastic prepayment and default model - moderate prepayment sensitivity, high default sensitivity

CMOprice_prepay_default(0.065/12, 10_000_000, 360,    # Mortgage parameters
                       0.002, 80.0,                   # Prepayment parameters
                       0.0005, 150.0,                 # Default parameters
                       0.045, 0.3, 0.05, 0.03, 10000) # CIR parameters / N

# Stochastic prepayment and default model - moderate prepayment sensitivity, higher baseline default

CMOprice_prepay_default(0.065/12, 10_000_000, 360,    # Mortgage parameters
                       0.002, 80.0,                   # Prepayment parameters
                       0.001, 100.0,                  # Default parameters
                       0.045, 0.3, 0.05, 0.03, 10000) # CIR parameters / N

# Stochastic prepayment and default model - moderate prepayment sensitivity, very high baseline default

CMOprice_prepay_default(0.065/12, 10_000_000, 360,    # Mortgage parameters
                       0.002, 80.0,                   # Prepayment parameters
                       0.002, 100.0,                  # Default parameters
                       0.045, 0.3, 0.05, 0.03, 10000) # CIR parameters / N

# Stochastic prepayment and default model - moderate prepayment and default sensitivities, low interest rates

CMOprice_prepay_default(0.065/12, 10_000_000, 360,    # Mortgage parameters
                       0.002, 80.0,                   # Prepayment parameters
                       0.0005, 100.0,                 # Default parameters
                       0.03, 0.3, 0.03, 0.03, 10000)  # CIR parameters / N

# Stochastic prepayment and default model - moderate prepayment and default sensitivities, high interest rates

CMOprice_prepay_default(0.065/12, 10_000_000, 360,    # Mortgage parameters
                       0.002, 80.0,                   # Prepayment parameters
                       0.0005, 100.0,                 # Default parameters
                       0.06, 0.3, 0.07, 0.03, 10000)  # CIR parameters / N

# Stochastic prepayment and default model - moderate prepayment and default sensitivities, increased rate volatility

CMOprice_prepay_default(0.065/12, 10_000_000, 360,    # Mortgage parameters
                       0.002, 80.0,                   # Prepayment parameters
                       0.0005, 100.0,                 # Default parameters
                       0.045, 0.3, 0.05, 0.06, 10000) # CIR parameters / N

# Stochastic prepayment and default model - moderate prepayment and default sensitivities, low mortgage rate

CMOprice_prepay_default(0.05/12, 10_000_000, 360,     # Mortgage parameters
                       0.002, 80.0,                   # Prepayment parameters
                       0.0005, 100.0,                 # Default parameters
                       0.045, 0.3, 0.05, 0.03, 10000) # CIR parameters / N

# Stochastic prepayment and default model - moderate prepayment and default sensitivities, high mortgage rate

CMOprice_prepay_default(0.08/12, 10_000_000, 360,     # Mortgage parameters
                       0.002, 80.0,                   # Prepayment parameters
                       0.0005, 100.0,                 # Default parameters
                       0.045, 0.3, 0.05, 0.03, 10000) # CIR parameters / N

# -----------------------------------------------------------------
# GREEKS (using central finite differences and common random seeds)
# -----------------------------------------------------------------

using Random

# Epsilon sizes
eps_r0 = 0.001          # 10 basis point bump in annualized initial interest rate
eps_sigma = 0.001       # Bump in interest rate volatility
eps_m = 0.0001          # Bump in monthly mortgage rate
eps_prepay_a = 0.0001   # Bump in base prepayment rate
eps_default_a = 0.00005 # Bump in base default rate

# Benchmark parameters
m = 0.065 / 12
L = 10_000_000
D = 360
prepay_a = 0.002
prepay_b = 80.0
default_a = 0.0005
default_b = 100.0
rzero = 0.045
alpha = 0.3
b = 0.05
sigma = 0.03
N = 10000

# Greek with respect to r0

Random.seed!(1234)
P_r0_plus = CMOprice_prepay_default(m, L, D, prepay_a, prepay_b, default_a, default_b,
    rzero + eps_r0, alpha, b, sigma, N).price

Random.seed!(1234)
P_r0_minus = CMOprice_prepay_default(m, L, D, prepay_a, prepay_b, default_a, default_b,
    rzero - eps_r0, alpha, b, sigma, N).price

dP_dr0 = (P_r0_plus - P_r0_minus) / (2 * eps_r0)

println("\nGreek estimate:")
println("dP/dr0 = ", dP_dr0)
println("10 bp effect ≈ ", dP_dr0 * 0.001)

# Greek with respect to sigma

Random.seed!(1234)
P_sigma_plus = CMOprice_prepay_default(m, L, D, prepay_a, prepay_b, default_a, default_b,
    rzero, alpha, b, sigma + eps_sigma, N).price

Random.seed!(1234)
P_sigma_minus = CMOprice_prepay_default(m, L, D, prepay_a, prepay_b, default_a, default_b,
    rzero, alpha, b, sigma - eps_sigma, N).price

dP_dsigma = (P_sigma_plus - P_sigma_minus) / (2 * eps_sigma)

println("\nGreek estimate:")
println("dP/dsigma = ", dP_dsigma)
println("per 1% increase in volatility ≈ ", dP_dsigma * 0.01)

# Greek with respect to mortgage rate m

Random.seed!(1234)
P_m_plus = CMOprice_prepay_default(m + eps_m, L, D, prepay_a, prepay_b, default_a, default_b,
    rzero, alpha, b, sigma, N).price

Random.seed!(1234)
P_m_minus = CMOprice_prepay_default(m - eps_m, L, D, prepay_a, prepay_b, default_a, default_b,
    rzero, alpha, b, sigma, N).price

dP_dm = (P_m_plus - P_m_minus) / (2 * eps_m)

println("\nGreek estimate:")
println("dP/dm = ", dP_dm)
println("10 bp effect ≈ ", dP_dm * 0.001)

# Greek with respect to prepay_a

Random.seed!(1234)
P_prepay_a_plus = CMOprice_prepay_default(m, L, D, prepay_a + eps_prepay_a, prepay_b, default_a, default_b,
    rzero, alpha, b, sigma, N).price

Random.seed!(1234)
P_prepay_a_minus = CMOprice_prepay_default(m, L, D, prepay_a - eps_prepay_a, prepay_b, default_a, default_b,
    rzero, alpha, b, sigma, N).price

dP_dprepay_a = (P_prepay_a_plus - P_prepay_a_minus) / (2 * eps_prepay_a)

println("\nGreek estimate:")
println("dP/d(prepay_a) = ", dP_dprepay_a)

# Greek with respect to default_a

Random.seed!(1234)
P_default_a_plus = CMOprice_prepay_default(m, L, D, prepay_a, prepay_b, default_a + eps_default_a, default_b,
    rzero, alpha, b, sigma, N).price

Random.seed!(1234)
P_default_a_minus = CMOprice_prepay_default(m, L, D, prepay_a, prepay_b, default_a - eps_default_a, default_b,
    rzero, alpha, b, sigma, N).price

dP_ddefault_a = (P_default_a_plus - P_default_a_minus) / (2 * eps_default_a)

println("\nGreek estimate:")
println("dP/d(default_a) = ", dP_ddefault_a)
