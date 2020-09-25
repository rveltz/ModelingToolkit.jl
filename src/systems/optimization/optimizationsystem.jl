"""
$(TYPEDEF)

A scalar equation for optimization.

# Fields
$(FIELDS)

# Examples

```
@variables x y z
@parameters σ ρ β

op = σ*(y-x) + x*(ρ-z)-y + x*y - β*z
os = OptimizationSystem(eqs, [x,y,z],[σ,ρ,β])
```
"""
struct OptimizationSystem <: AbstractSystem
    """Vector of equations defining the system."""
    op::Any
    """Unknown variables."""
    states::Vector
    """Parameters."""
    ps::Vector
    pins::Vector
    observed::Vector{Equation}
    equality_constraints::Vector{Equation}
    inequality_constraints::Vector
    """
    Name: the name of the system
    """
    name::Symbol
    """
    systems: The internal systems
    """
    systems::Vector{OptimizationSystem}
end

function OptimizationSystem(op, states, ps;
                            pins = [],
                            observed = [],
                            equality_constraints = Equation[],
                            inequality_constraints = [],
                            name = gensym(:OptimizationSystem),
                            systems = OptimizationSystem[])
    OptimizationSystem(value(op), value.(states), value.(ps), value.(pins), observed, equality_constraints, inequality_constraints, name, systems)
end

function calculate_gradient(sys::OptimizationSystem)
    expand_derivatives.(gradient(equations(sys), states(sys)))
end

function generate_gradient(sys::OptimizationSystem, vs = states(sys), ps = parameters(sys); kwargs...)
    grad = calculate_gradient(sys)
    return build_function(grad, vs, ps;
                          conv = AbstractSysToExpr(sys),kwargs...)
end

function calculate_hessian(sys::OptimizationSystem)
    expand_derivatives.(hessian(equations(sys), states(sys)))
end

function generate_hessian(sys::OptimizationSystem, vs = states(sys), ps = parameters(sys);
                          sparse = false, kwargs...)
    hes = calculate_hessian(sys)
    if sparse
        hes = sparse(hes)
    end
    return build_function(hes, vs, ps;
                          conv = AbstractSysToExpr(sys),kwargs...)
end

function generate_function(sys::OptimizationSystem, vs = states(sys), ps = parameters(sys); kwargs...)
    return build_function(equations(sys), vs, ps;
                          conv = AbstractSysToExpr(sys),kwargs...)
end

equations(sys::OptimizationSystem) = isempty(sys.systems) ? sys.op : sys.op + reduce(+,namespace_expr.(sys.systems))
namespace_expr(sys::OptimizationSystem) = namespace_expr(sys.op,sys.name,nothing)

hessian_sparsity(sys::OptimizationSystem) =
    hessian_sparsity(sys.op, states(sys))

"""
```julia
function DiffEqBase.OptimizationProblem{iip}(sys::OptimizationSystem,
                                          parammap=DiffEqBase.NullParameters();
                                          u0=nothing, lb=nothing, ub=nothing,
                                          hes = false, sparse = false,
                                          checkbounds = false,
                                          linenumbers = true, parallel=SerialForm(),
                                          kwargs...) where iip
```

Generates an OptimizationProblem from an OptimizationSystem and allows for automatically
symbolically calculating numerical enhancements.
"""
function DiffEqBase.OptimizationProblem{iip}(sys::OptimizationSystem,
                                          parammap=DiffEqBase.NullParameters();
                                          u0=nothing, lb=nothing, ub=nothing,
                                          hes = false, sparse = false,
                                          checkbounds = false,
                                          linenumbers = true, parallel=SerialForm(),
                                          kwargs...) where iip
    dvs = states(sys)
    ps = parameters(sys)

    f = generate_function(sys,checkbounds=checkbounds,linenumbers=linenumbers,
                              parallel=parallel,expression=Val{false})
    u0 = varmap_to_vars(u0,dvs)
    p = varmap_to_vars(parammap,ps)
    lb = varmap_to_vars(lb,dvs)
    ub = varmap_to_vars(ub,dvs)
    OptimizationProblem(f,p;u0=u0,lb=lb,ub=ub,kwargs...)
end

"""
```julia
function DiffEqBase.OptimizationProblemExpr{iip}(sys::OptimizationSystem,
                                          parammap=DiffEqBase.NullParameters();
                                          u0=nothing, lb=nothing, ub=nothing,
                                          hes = false, sparse = false,
                                          checkbounds = false,
                                          linenumbers = true, parallel=SerialForm(),
                                          kwargs...) where iip
```

Generates a Julia expression for an OptimizationProblem from an
OptimizationSystem and allows for automatically symbolically
calculating numerical enhancements.
"""
struct OptimizationProblemExpr{iip} end

function OptimizationProblemExpr{iip}(sys::OptimizationSystem,
                                          parammap=DiffEqBase.NullParameters();
                                          u0=nothing, lb=nothing, ub=nothing,
                                          hes = false, sparse = false,
                                          checkbounds = false,
                                          linenumbers = false, parallel=SerialForm(),
                                          kwargs...) where iip
    dvs = states(sys)
    ps = parameters(sys)

    f = generate_function(sys,checkbounds=checkbounds,linenumbers=linenumbers,
                              parallel=parallel,expression=Val{true})
    u0 = varmap_to_vars(u0,dvs)
    p = varmap_to_vars(parammap,ps)
    lb = varmap_to_vars(lb,dvs)
    ub = varmap_to_vars(ub,dvs)
    quote
        f = $f
        p = $p
        u0 = $u0
        lb = $lb
        ub = $ub
        OptimizationProblem(f,p;u0=u0,lb=lb,ub=ub,kwargs...)
    end
end
