
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
or_query(x1::NotmuchLeaf{:from}, x2::NotmuchLeaf{:to}) =
    x1.value == x2.value ? NotmuchLeaf{:fromto}(x1.value) :
    NotmuchQueryOperator{:or}(Any[x1, x2])
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


# plain renderer (no styles)
render(x::NotmuchLeaf{Symbol(" ")}) = string(x.value)
render(x::NotmuchLeaf{:from})   = "from:$(x.value)"
render(x::NotmuchLeaf{:to})     = "to:$(x.value)"
render(x::NotmuchLeaf{:fromto}) = "(from:$(x.value) or to:$(x.value))"
render(x::NotmuchLeaf{:tag})    = "tag:$(x.value)"
render(x::NotmuchLeaf{:id})     = "id:$(x.value)"
render(x::NotmuchLeaf{:thread}) = "thread:$(x.value)"
render(x::NotmuchLeaf{:date})   = "date:$(x.value)"
render(x::NotmuchLeaf{:folder}) = "folder:$(x.value)"
render(x::NotmuchLeaf{:subject})= "subject:$(x.value)"
render(x::NotmuchLeaf{:not})    = "not $(x.value isa NotmuchQueryOperator ? "(" * render(x.value) * ")" : render(x.value))"

render(x::NotmuchQueryOperator{op}) where {op} =
    "(" * join(render.(x.subqueries), " $(op) ") * ")"

# Stable plain renderer (machine)
qplain(q::Query) = render(normalize(q))

normalize(q::NotmuchLeaf) = q

function normalize(q::NotmuchQueryOperator{op}) where {op}
    subs = map(normalize, q.subqueries)
    # Flatten nested same-op
    flat = reduce(Any[], subs) do acc, s
        if s isa NotmuchQueryOperator{op}
            append!(acc, s.subqueries)
        else
            push!(acc, s)
        end
        acc
    end
    # Idempotence and set-like behavior for and/or
    uniq = if op in (:and, :or, Symbol(" "))
        # de-duplicate leaves by hash; keep order stable-ish
        seen = Set{UInt}()
        out = Any[]
        for e in flat
            h = hash(e)
            if !(h in seen)
                push!(out, e); push!(seen, h)
            end
        end
        out
    else
        flat
    end

    # Special rule: (from:x or to:x) -> fromto:x, even after flatten
    if op == :or
        leaves = filter(x -> x isa NotmuchLeaf, uniq)
        rest   = filter(x -> !(x isa NotmuchLeaf), uniq)
        # Group by value for from/to
        ft = Dict{Any,Tuple{Bool,Bool}}()
        for l in leaves
            if l isa NotmuchLeaf{:from}
                ft[l.value] = (true, get(ft, l.value, (false,false))[2])
            elseif l isa NotmuchLeaf{:to}
                ft[l.value] = (get(ft, l.value, (false,false))[1], true)
            end
        end
        out = Any[]
        for l in leaves
            if l isa NotmuchLeaf{:from} && get(ft, l.value, (false,false)) == (true,true)
                # skip from; emit fromto once later
            elseif l isa NotmuchLeaf{:to} && get(ft, l.value, (false,false)) == (true,true)
                # skip to
            else
                push!(out, l)
            end
        end
        # add fromto leaves
        for (v,(hf,ht)) in ft
            if hf && ht
                push!(out, NotmuchLeaf{:fromto}(v))
            end
        end
        uniq = vcat(out, rest)
    end

    NotmuchQueryOperator{op}(uniq)
end
