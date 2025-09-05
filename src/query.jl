
@auto_hash_equals struct NotmuchQueryOperator{op}
    subqueries::Vector{Any}
end
@auto_hash_equals struct NotmuchLeaf{op}
    value::Any
end




Query = Union{NotmuchQueryOperator,NotmuchLeaf}
space_query(x) = x
space_query(x1,x...) = NotmuchQueryOperator{Symbol(" ")}(Any[x1,x...])
space_query(x1::NotmuchQueryOperator{Symbol(" ")},x...) = NotmuchQueryOperator{Symbol(" ")}(Any[x1.subqueries...,x...])

and_query(x) = x
and_query(x1,x...) = NotmuchQueryOperator{:and}(Any[x1,x...])
and_query(x1::NotmuchQueryOperator{:and},x...) = NotmuchQueryOperator{:and}(Any[x1.subqueries...,x...])


or_query(x) = x
or_query(x1::NotmuchLeaf{:from},x2::NotmuchLeaf{:to}) =
    if x1.value==x2.value
        NotmuchLeaf{:fromto}(x1.value)
    else
        NotmuchQueryOperator{:or}(Any[x1,x...])
    end
or_query(x1,x...) = NotmuchQueryOperator{:or}(Any[x1,x...])
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




function Base.show(io::IO,x::Union{NotmuchQueryOperator, NotmuchLeaf})
    print(io, annotatedstring(x))
end

function StyledStrings.annotatedstring(x::NotmuchLeaf{:not})
    if x.value isa NotmuchQueryOperator
        styled"{bright_red:not} ({bright_red:$(x.value)})"
    else
        styled"{bright_red:not} {bright_red:$(x.value)}"
    end
end

function StyledStrings.annotatedstring(x::NotmuchLeaf{Symbol(" ")})
    styled"{black:$(x.value)}"
end
function StyledStrings.annotatedstring(x::NotmuchLeaf{op}) where op
    colors = Dict(:tag => :cyan, :from => :underline, :fromto => :underline, :to => :underline, Symbol(" ") => :black)
    col = (get(colors,op,:underline))
    styled"{$col:$op}:{$col:$(x.value)}"
end

function StyledStrings.annotatedstring(x::NotmuchQueryOperator{op}) where op
    "(" * join(annotatedstring.(x.subqueries), " $op ")* ")"
end



qstring(x) = annotatedstring(x)
function qstring(x::NotmuchLeaf{:fromto}) 
    styled"{underline:from}:{underline:$(x.value)} or {underline:to}:{underline:$(x.value)}"
end

function qstring(x::NotmuchQueryOperator{op}) where op
    "(" * join(qstring.(x.subqueries), " $op ")* ")"
end
Base.string(x::Query) = qstring(x)
