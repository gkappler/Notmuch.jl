
@auto_hash_equals struct NotmuchQueryOperator{op}
    subqueries::Vector{Any}
end
@auto_hash_equals struct NotmuchLeaf{op}
    value::Any
end

function StyledStrings.annotatedstring(x::NotmuchLeaf{:not})
    if x.value isa NotmuchQueryOperator
        styled"{bright_red:not} ({bright_red:$(x.value)})"
    else
        styled"{bright_red:not} {bright_red:$(x.value)}"
    end
end

function StyledStrings.annotatedstring(x::NotmuchLeaf{op}) where op
    colors = Dict(:tag => :light_blue, :from => :yellow, :fromto => :yellow, :to => :green)
    styled"{$(get(colors,op,:white)):$op}:{$(get(colors,op,:white)):$(x.value)}"
end
function StyledStrings.annotatedstring(x::NotmuchQueryOperator{op}) where op
    join(annotatedstring.(x.subqueries), " $op ")
end

Base.show(io::IO,x::Union{NotmuchQueryOperator, NotmuchLeaf}) =
    print(io, annotatedstring(x))


StyledStrings.annotatedstring(x::NotmuchQueryOperator{:and}) =
    "(" * join(annotatedstring.(x.subqueries), " and ") * ")"

StyledStrings.annotatedstring(x::NotmuchQueryOperator{:or}) =
    "(" * join(annotatedstring.(x.subqueries), " or ") * ")"

Query = Union{NotmuchQueryOperator,NotmuchLeaf}
and_query(x) = x
or_query(x) = x
and_query(x1,x...) = NotmuchQueryOperator{:and}(Any[x1,x...])
or_query(x1::NotmuchLeaf{:from},x2::NotmuchLeaf{:to}) =
    if x1.value==x2.value
        NotmuchLeaf{:fromto}(x1.value)
    else
        NotmuchQueryOperator{:or}(Any[x1,x...])
    end
or_query(x1,x...) = NotmuchQueryOperator{:or}(Any[x1,x...])
and_query(x1::NotmuchQueryOperator{:and},x...) = NotmuchQueryOperator{:and}(Any[x1.subqueries...,x...])
or_query(x1::NotmuchQueryOperator{:or},x...) = NotmuchQueryOperator{:or}(Any[x1.subqueries...,x...])

using Dates
date_query(from::AbstractString, to::AbstractString) =
    NotmuchLeaf{:date}("@$(from)..@$(to)")
function date_query(from::DateTime, to::DateTime)
    function unixstring(x)
        string(convert(Int64,round(datetime2unix(round(x, Second)))))
    end
    date_query(unixstring(from),
               unixstring(to))
end
