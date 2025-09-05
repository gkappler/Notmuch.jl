export Email

"""
    Headers

struct wrapping notmuch json header format.
"""
struct Headers
    Subject::String
    From::String
    To::String
    Cc::String
    Date::DateTime #  format: Sat, 28 May 2022 10:03:20 +0100
end
headerfield(::Val{:Date}, x::Nothing) = now()
headerfield(::Val{:Date}, s::AbstractString) =
    parse(DateTimeParser("e, d u y H:M:S"), s)

headerfield(::Val, x) = x

headerfield(::Val, x::Nothing) = ""

function StyledStrings.annotatedstring(x::Headers) 
    styled"{date:$(x.Date)}\n$(x.Subject)\nFrom: {from:$(x.From)}"  *
        (isempty(x.To) ? "" : styled"\nTo: {To:$(x.To)}") *
        (isempty(x.Cc) ? "" : styled"\nCc: {Cc:$(x.Cc)}") *
         "\n"
end
Base.show(io::IO,x::Headers) = print(io,annotatedstring(x))
    
function Headers(x)
    Headers((headerfield(Val{k}(), get(x,replace("$k", '_' => '-'), nothing))
             for k in fieldnames(Headers))...)
end

#trim(x) = replace(x, r"^[ \n\t\r]+" => "", r"[ \n\t\r]+$" => "")

"""
    PlainContent{type}

struct wrapping notmuch json content format.
"""
struct PlainContent{type}
    id::Int
    content::String
end

struct Content{type}
    id::Union{Nothing,Int}
    content_charset::Union{Nothing,String} # ?
    content::Any # ?
    content_transfer_encoding::Union{Nothing,String}
    content_length::Union{Nothing,Int}
end
Base.show(io::IO, x::Content{Symbol("text/plain")}) =
    print(io,chomp(x.content))

function Base.show(io::IO, x::Content{Symbol("multipart/mixed")}) 
    print(io,x.content[1])
end
function Base.show(io::IO, x::Content{Symbol("multipart/alternative")}) 
    print(io,x.content[1])
end
function Base.show(io::IO, x::Content{Symbol("multipart/related")}) 
    print(io,x.content[1])
end

find(pred::MIME{mime}, x::PlainContent) where mime =
    nothing

find(pred::MIME{Symbol("text/plain")}, x::PlainContent) =
    x

find(pred::MIME{mime}, x::Content{Symbol("text/plain")}) where mime =
    x

function find(pred::MIME{mime}, x::Content{Symbol("multipart/mixed")}) where mime 
    for sc in x.content
        r = find(sc)
        r !== nothing && return r
    end
end

contentfield(::Val, x::Union{Nothing,AbstractString, Number}) = x
contentfield(::Val{:content}, x::Union{Nothing,AbstractString, Number}) = x
function contentfield(::Val{:content}, x)
    Content(x)
end
function contentfield(::Val{:content}, x::AbstractVector)
    Content.(x)
end

function Content(x::AbstractVector)
    #@show x
    Content.(x)
end

function Content(x::JSON3.Object)
    # @show x
    ct = get(x, "content-type", nothing)
    if ct === nothing
        @warn "unknown" x
        error("$x")
    else
        Content{Symbol(ct)}(
            (contentfield(Val{k}(), get(x,replace("$k", '_' => '-'), nothing))
             for k in fieldnames(Content))...)
    end
end

tagsymbols = Dict(
    # "inbox" => "📥",
    # "attachment" => "📎",
    # "new" => "🆕",
    # "spam" => "🤦",
    # "unread" => "📩",
)

function printtag(io::IO,x)
    printstyled(io, "",
                get(tagsymbols,x) do
                    ":"*x
                end; color=:cyan)
end

"""
    Email

struct wrapping notmuch json email format.
"""
struct Email
    id::String
    match::Bool
    excluded::Bool
    filename::Vector{String}
    timestamp::DateTime
    date_relative::String
    tags::Vector{String}
    body::Vector{Content} ## TODO: COntent
    crypto::Vector{String}
    headers::Headers
end
Email(Nothing) = nothing
Email(o::JSON3.Object) =
    Email((showfield(Val{k}(), get(o,"$k",nothing))
           for k in fieldnames(Email))...)
function Email(id::AbstractString; body=false, kw...)
    r = flatten(notmuch_show("id:$id"; body = body, kw...))
    isempty(r) ? nothing : Email(first(r))
end
show(id::AbstractString; body=false, kw...) =
    first(flatten(notmuch_show("id:$id"; body = body, kw...)))

function pretty_email(x)
    r = tryparse(email_parser,x)
    r === nothing ? x : r
end
function Base.show(io::IO, x::Email)
    if get(io, :compact, false)
        showline(io,x)
    else
        ae = pretty_email(x.headers.From)
        printstyled(io, x.date_relative, " ")
        print(io, pretty_email(x.headers.From), " => ", pretty_email.(x.headers.To))
        println(io)
        printstyled(io, x.headers.Subject, " "; bold=false)
        for t in x.tags
            printtag(io,t)
        end
        for c in x.body
            print(io, "\n", c)
        end
        ##println(io)
    end
end

function Base.show(io::IO, ::MIME"text/html", x::Email)
        #ae = tryparse(author_email,x.headers.From)
        println(io, "<div><span class=\"date\">", x.date_relative, "</span>")
        println(io, "<span class=\"from\">", x.headers.From, "</span>")
        for t in x.tags
            println(io, "<span class=\"tag\">", t, "</span>")
        end
        println(io,"</div")
        println(io, "<div class=\"\">")
        println(io, "<span class=\"subject\">", x.headers.Subject, "</span>")
        for c in x.body
            print(io, "\n", c)
        end
        println(io,"</div")
end


showline(x::Email) =
    showline(stdout,x)

function showline(io::IO, x::Email)
    ae = pretty_email(x.headers.From)
    printstyled(io, x.timestamp, " ")
    print(io, ae)
    print(io,": ")
    printstyled(io, x.headers.Subject, " "; bold=false)
    for t in x.tags
        printtag(io,t)
    end
    ##println(io)
end

showfield(::Val, x::Union{AbstractString, Bool, Number}) = x
showfield(::Val, x::Union{AbstractArray}) = collect(x)

showfield(::Val{:body}, x::Union{AbstractArray}) =  Content(x)
showfield(::Val{:body}, x::Nothing) = []

showfield(::Val{:crypto}, x) = []

showfield(::Val{:headers}, x) = Headers(x)

showfield(::Val{:timestamp}, x::Int) =
    Dates.unix2datetime(x)

"""
    WithReplies{M,R}

type to hold a nested reply tree.
[`notmuch_tree`](@ref)
"""
struct WithReplies{M,R}
    message::M
    replies::R
    WithReplies(m::Union{Email, Nothing}, x::Vector) =
        isempty(x) ? m : new{typeof(m), typeof(x)}(m,x)
end
WithReplies(m::Union{Email, Nothing}, x::Union{WithReplies,Email}) =
    WithReplies(m, [x])


keepit(x::Nothing) = false
keepit(x::Email) = true
keepit(x::WithReplies) = true
keepit(x::AbstractVector) = !isempty(x)

simplify(x) = WithReplies(x)
export flatten
flatten(x::WithReplies) =
    flatten!(Email[],x)
flatten(x::AbstractVector) =
    flatten!([],x)

flatten!(r::AbstractVector, x::Nothing) =
    r

function flatten!(r::Vector, x::WithReplies) 
    x.message !== nothing && push!(r, x.message)
    for e in x.replies
        flatten!(r,e)
    end
    r
end

function flatten!(r::Vector, x::AbstractArray) 
    for e in x
        flatten!(r,e)
    end
    r
end

function flatten!(r::Vector, x::JSON3.Object) 
    push!(r, x)
    r
end

function flatten!(r::Vector, x::Email) 
    push!(r, x)
    r
end


using AbstractTrees
Base.show(io::IO, x::WithReplies) = print_tree(io,x)
import AbstractTrees: printnode

AbstractTrees.printnode(io::IO, x::WithReplies) =
    show(io,x.message)
AbstractTrees.printnode(io::IO, x::WithReplies{Nothing}) =
    nothing
AbstractTrees.printnode(io::IO, x::Nothing) =
    nothing
AbstractTrees.children(x::WithReplies) =
    x.replies


function withReply(x)
    o, c = x
    try
        s = Email(o)
        if isempty(c)
            s
        else
            WithReplies(s,Emails.(c))
        end
    catch e
        @error "failed $e" x e
        # readline()
    end
end

"""
    Emails(x)

Transformation function to pass to [`notmuch_show`](@ref).

```jldoctest
julia> notmuch_tree(Emails, "tag:elmail")
```
"""
Emails(x::Nothing) = nothing
function Emails(x::AbstractVector)
    isempty(x) && return nothing
    if length(x) == 2 && ( x[1] isa Union{Nothing,JSON3.Object} )
        withReply(x)
    else
        WithReplies(nothing,Emails.(x))
    end
end
export Emails
