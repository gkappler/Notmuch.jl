
optionstring(x::AbstractVector; kw...) =
    vcat([ optionstring(e;kw...) for e in pairs(x) ]...)
optionstring(x::AbstractDict{<:Key}; kw...) =
    vcat([ optionstring(e;kw...) for e in pairs(x) ]...)
optionstring(x::Pair{String}; kw...) =
    optionstring(Symbol(x.first) => x.second; kw...)
function optionstring(x::Pair{Symbol};omit=x->false)
    if omit(x.first)
        optionstring(Val{x.first}(), x.second)
    elseif x.second == ""
        ["--$(x.first)"]
    else
        ["--$(x.first)=$(x.second)"]
    end
end


"""
    optionstring(...)

Internally constructs notmuch Cmd arguments from API queries.
Works but should be simplified.
"""
optionstring(::Val{:base_query}, x) = [ ]
optionstring(::Val{:sub_queries}, x) = [ ]
optionstring(::Val{:q}, x) = [ ]
optionstring(::Val{:tags}, x) = [ ]
optionstring(::Val{:user}, x) = [ ]
export optionstring



"""
    omitq(x)
    omitqtags(x)

`q` is the query parameter for the search argument in notmuch.

Where it applies (`notmuch tag`) `tags` is the tag flag query `+add` and `-remove`.

Other query parameters are passed as is to `notmuch` as `--setting=value`.
"""
omitq(x) = x == :q || x == :user
omitqtags(x) = omitq(x) || (x==:tags)
export omitqtags, omitq
