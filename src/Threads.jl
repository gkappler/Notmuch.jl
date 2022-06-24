export Thread2
using Dates
struct Thread2
    thread::String # id
    timestamp::DateTime
    date_relative::String
    matched::Int
    total::Int
    authors::String
    subject::String
    query::Vector{String}
    tags::Vector{String}
end
import Base: show

function Base.show(io::IO, x::Thread2)
    print(io, x.date_relative, " ")
    printstyled(io, x.subject, "\n"; bold=true)
    printstyled(io, " "^(length(x.date_relative)+2), x.authors; color=:yellow)
    for t in x.tags
        printstyled(io, " ", "#"*t; color=:cyan)
    end
end

threadfieldt(::Val, f) = f
threadfieldt(::Val{:timestamp}, f::Int) = Dates.unix2datetime(f)
threadfieldt(::Val, f::Nothing) = ""
threadfieldt(::Val{:query}, f) = String[ filter(x->x!==nothing,f)... ]

threadfield(x::AbstractDict{Symbol}, ::Val{k}) where k =
    threadfieldt(Val{k}(), x[k])

threadfield(x::Union{<:JSON3.Object,<:AbstractDict{<:AbstractString}},
            ::Val{k}) where k =
     threadfieldt(Val{ k}(),  x["$k"])


Thread2(x) =
    Thread2(( threadfield(x,Val{k}()) for k in fieldnames(Thread2) )...)
