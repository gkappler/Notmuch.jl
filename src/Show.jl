export Email

"""
    Headers

struct wrapping notmuch json header format.
"""
struct Headers
    Subject::String
    From::String
    To::String
    Date::DateTime #  format: Sat, 28 May 2022 10:03:20 +0100
end
headerfield(::Val{:Date}, x::Nothing) = now()
headerfield(::Val{:Date}, s::AbstractString) =
    parse(DateTimeParser("e, d u y H:M:S"), s)

headerfield(::Val, x) = x

headerfield(::Val, x::Nothing) = ""

    
function Headers(x)
    Headers((headerfield(Val{k}(), get(x,replace("$k", '_' => '-'), nothing))
             for k in fieldnames(Headers))...)
end


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
    print(io,replace(x.content, r"\n+$" => "" ))


contentfield(::Val, x::Union{Nothing,AbstractString, Number}) = x
contentfield(::Val{:content}, x::Union{Nothing,AbstractString, Number}) = x
function contentfield(::Val{:content}, x)
    Content(x)
end
function contentfield(::Val{:content}, x::AbstractVector)
    Content.(x)
end

function Content(x::JSON3.Object)
    # @show x
    Content{Symbol(x["content-type"])}(
        (contentfield(Val{k}(), get(x,replace("$k", '_' => '-'), nothing))
         for k in fieldnames(Content))...)
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
    body::Vector{Content}
    crypto::Vector{String}
    headers::Headers
end
Email(Nothing) = nothing
Email(o::JSON3.Object) =
    Email((showfield(Val{k}(), get(o,"$k",nothing))
           for k in fieldnames(Email))...)

function Base.show(io::IO, x::Email)
    ae = author_email(x.headers.From)
    print(io, x.date_relative, " ")
    printstyled(io, ae.name == "" ? ae.email : ae.name; color=:yellow)
    for t in x.tags
        printstyled(io, " ", "#"*t; color=:cyan)
    end
    println(io)
    printstyled(io, x.headers.Subject; bold=true, underline=true)
    for c in x.body
        print(io, "\n", c)
    end
end

showfield(::Val, x::Union{AbstractString, Bool, Number}) = x
showfield(::Val, x::Union{AbstractArray}) = collect(x)

showfield(::Val{:body}, x::Union{AbstractArray}) =  Content.(x)
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

    
struct Mailbox
    user::String
    domain::String
end
function Base.show(io::IO, x::Mailbox)
    printstyled(io, x.user; color = :yellow)
    printstyled(io, "@", x.domain; color = :light_yellow)
end
## is this official??

using CombinedParsers
alpha = CharIn('a':'z','A':'Z')
alphanum = CharIn('a':'z','A':'Z','0':'9')
extrachar = CharIn("-+_.~")
email_regexp = Sequence(
    !(CharIn(extrachar,alpha)*Repeat(CharIn(extrachar,alphanum))),
    "@",!Repeat1(CharIn(CharIn("-."),alphanum))) do v
        Mailbox(v[1], v[3])
    end

author_email = Either(
    Sequence(
        :name => !Repeat(CharNotIn('<')),
        CombinedParsers.horizontal_space_maybe,"<",
        :email => email_regexp,
        ">"),
    map(email_regexp) do v
        (name = "",
         email =v)
    end
)

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
