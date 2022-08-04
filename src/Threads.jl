export Thread
using Dates
struct Thread
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

function Base.show(io::IO, x::Thread)
    print(io, x.date_relative, " ")
    printstyled(io, x.subject, "\n"; bold=true)
    printstyled(io, " "^(length(x.date_relative)+2), x.authors; color=:yellow)
    for t in x.tags
        printstyled(io, " ", "#"*t; color=:cyan)
    end
end

threadfieldt(::Val, f) = f
threadfieldt(::Val{:timestamp}, f::Int64) =
    if f < -1059406758 ## number overflow bug in notmuch, workaround excluding before 1938!
        Dates.unix2datetime(typemax(Int32) - (typemin(Int32) - f))
    elseif f < 0
        Dates.unix2datetime(0)-Second(@show -f)
    else Dates.unix2datetime(f)
        f < 0 ? Dates.unix2datetime(typemax(Int32) - (typemin(Int32) - f)) : Dates.unix2datetime(f)
    end

threadfieldt(::Val, f::Nothing) = ""
threadfieldt(::Val{:query}, f) = String[ filter(x->x!==nothing,f)... ]

threadfield(x::AbstractDict{Symbol}, ::Val{k}) where k =
    threadfieldt(Val{k}(), x[k])

threadfield(x::Union{<:JSON3.Object,<:AbstractDict{<:AbstractString}},
            ::Val{k}) where k =
     threadfieldt(Val{ k}(),  x["$k"])


Thread(x) =
    Thread(( threadfield(x,Val{k}()) for k in fieldnames(Thread) )...)
