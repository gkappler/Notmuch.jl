"""
`Notmuch.jl` opens maildir email data up for analyses in Julia by
providing a julia `Cmd` wrapper for [notmuch mail](https://notmuchmail.org/)
database supporting arbitrary tags and advanced search.

Notmuch mail indexes emails into a xapian database from a maildir store.

maildir 
- is an standard for email datasets.
- can be smoothly synchronized with an IMAP server by [offlineimap](http://www.offlineimap.org/).

Genie routes are provided exposing notmuch search as an HTTP API.
"""
module Notmuch
using DataFrames
using StyledStrings
using PrettyTables
using JSON3
using Logging, LoggingExtras
using AutoHashEquals

ToF = Union{Type,Function}
LIMIT = 5
trash(f) = println("rm $f")


include("query.jl")
include("tag.jl")
include("Show.jl")
include("updates.jl")
include("parsers.jl")
include("attachments.jl")
include("Threads.jl")
include("user.jl")

export notmuch_json, notmuch_search, notmuch_tree, notmuch_count, notmuch_cmd

"""
    notmuch_cmd(command, x...; log=false, kw...)

Build notmuch `command` with arguments `x...`.

For user `kw...` see [`userENV`](@ref).

Used in [`notmuch_json`](@ref) and  [`notmuch`](@ref).
"""
function notmuch_cmd(command, x...; log=false, kw...)
    env = userENV(; kw...)
    cfg = ".notmuch-config"
    y = [x...]
    c = Cmd(`/usr/bin/notmuch --config=$cfg $command $y`,
            env=env,
            dir=env["HOME"])
    log && @info "notmuch cmd" c
    c
end

export notmuch
"""
    notmuch(x...; kw...)

Run [`notmuch_cmd`](@ref) and return output as `String`.

See [`notmuch_json`](@ref)
To get json as a String, provide `"--format=json"` as argument.

For user `kw...` see [`userENV`](@ref).
"""
function notmuch(x...; kw...)
    r = try
        read(notmuch_cmd(string.(x)...; kw...), String)
    catch e
        @error "notmuch error" e
    end
    r
end


"""
    notmuch_json(command,x...; kw...)

Parse [`notmuch`](@ref) with `JSON3.read`.

For user `kw...` see [`userENV`](@ref).
"""
function notmuch_json(command,x...; kw...) 
    r = notmuch(command, "--format=json", x...; kw...)
    r === nothing && return []
    JSON3.read(r)
end

"""
    notmuch_count(x...; kw...)
"""
function notmuch_count(x...; kw...)
    c = notmuch("count", x...; kw...)
    c === nothing && return 0
    parse(Int,chomp(c))
end


function counts(basq, a...; subqueries=String[], kw...)
    if isempty(subqueries)
        [ notmuch_count(a..., basq;kw...) ]
    else
        [ parse(Int,chomp(Notmuch.notmuch(
            "count", basq !== nothing ? "($basq) and ($t)" : t;
            kw...)))
          for t in subqueries ]
    end
end

function search_tags(query, a...; kw...)
    Notmuch.notmuch_json("search", "--output=tags", a..., query; kw...)
end



function tagcounts(query, a...; kw...)
    ts = Notmuch.notmuch_json("search", "--output=tags", a..., query; kw...)
    iob = IOBuffer()
    open(
        Notmuch.notmuch_cmd(
            "count", "--batch"; kw...
                ),
        "w", iob) do io
            for t in ts
                println(io, "($query) and tag:$t")
            end
        end
    result = split(String(take!(iob)),"\n")
    sort([ (tag=t, count=parse(Int,c))
          for (t,c) in zip(ts,result) ]; by = x -> x[2])
end



"""
    notmuch_search(query, x...; offset=0, limit=LIMIT, kw...)
    notmuch_search(T::Union{Type,Function}, x...; kw...)

Search notmuch and return threads json `Vector`.

With first argument `f::Union{Type,Function}` each result is converted with calling `f`, otherwise JSON is returned.

For user `kw...` see [`userENV`](@ref).

"""
notmuch_search(query, x...; offset=0, limit=5, kw...) =
    notmuch_json(:search, "--offset=$offset", "--limit=$limit", x..., query; kw...)
notmuch_search(T::ToF, x...; kw...) =
    T.(notmuch_search(x...; kw...))
export notmuch_search

export notmuch_ids
function notmuch_ids(q; limit = missing, kw...)
    limit === missing && (limit = Notmuch.notmuch_count(q; kw...))
    return limit > 0 ?
        Notmuch.notmuch_search(q, "--limit=$limit", "--output=messages"; kw...) :
        String[]
end
"""
    notmuch_address(q, a...; target=1000, kw...)

call `notmuch address`.
Notmuch adress collection can take long and collect a long list of addresses when run on 100ks of messages.
`notmuch_address` does a binary search to limits the time range to match `target` messages. 

TODO: currently the maximum date is fixed, and the most recent `target` commands are returned.

"""
function notmuch_address(q, a...; target=1000, kw...)
    if target !== nothing
        tc = time_counts(q; target=target, kw... )
        tc === nothing && return (timespan_counts = [], address = [], count = 0)
        span=tc.probes[end]
        from = span.from
        to = span.to
        timec = date_query(from,to)
        q_ = "($q) and ($timec)"
        (timespan_counts = tc.probes
         , address = notmuch_json( :address, a...,  q_; kw..., log=true)
         , count = notmuch_count(q_))
    else
        (timespan_counts = []
         , address = notmuch_json( :address, a...,  q; kw..., log=true))
    end
end
export notmuch_address


"""
    notmuch_show(query, x...; body = true, entire_thread=false, kw...)
    notmuch_show(T::Union{Type,Function}, x...; kw...)

`notmuch_search` for `query` and return `notmuch show` for each resulting thread.
(This filtering through threads returns not too long list of first results. You can use `limit` and `offset` keywords.)

With first argument `f::Union{Type,Function}` each result is converted with calling `f`, otherwise JSON is returned.

For user `kw...` see [`userENV`](@ref).
"""
function notmuch_show(query, x...; body = true, entire_thread=false, offset = 0, limit = LIMIT, kw...)
    tids = [ t.thread for t in notmuch_search(query, x...; offset = offset, limit = limit, kw...) ]
    isempty(tids) && return []
    ##@debuginfo "show" query x tids
    threadq = join("thread:" .* tids, " or ")
    notmuch_json(:show, x..., "--body=$body", "--entire-thread=$(entire_thread)",
                 "($query) and ($threadq)"; kw...)
end


notmuch_show(T::ToF, x...; kw...) = T(notmuch_show(x...; kw...))
export notmuch_show

"""
    notmuch_tree(x...; body = false, entire_thread=false, kw...)
    notmuch_tree(T::Union{Type,Function}, x...; kw...)

Parsimonous tree query for fetching structure, convenience query for 
[`notmuch_show`](@ref)

With first argument `f::Union{Type,Function}` each result is converted with calling `f`, otherwise JSON is returned.

For user `kw...` see [`userENV`](@ref).
"""
notmuch_tree(x...; body = false, entire_thread=false, kw...) =
    notmuch_show(x...; body = body, entire_thread=entire_thread, kw...)
notmuch_tree(T::ToF, x...; kw...) = T(notmuch_tree(x...; kw...))
export notmuch_tree





export notmuch_files
notmuch_files(q; kw...) =
    notmuch_search(q,"--output=files"; kw...)


function userEmail(user)
    host = get(ENV,"host", "Notmuch")
    user === nothing ? "elmail_api_tag@" * host : user * "@" * host
end

# Export the correct names
export queue_mail, send_outbox, outbox_ids, smtp_settings_map, SMTPSettings
export rfc_mail

"""
        function rfc_mail(; from, to=String[], cc=String[], bcc=String[], subject, content,
                  replyto="",
                  message_id = "",
                  in_reply_to="",
                  references="",
                  date = now(),
                  keywords = String[], kw... )

Return a `String` in RFC mail format.

Joins `keywords` to `,` separated list and adds as `X-Keywords` to headers.

See [`SMTPClient.get_body`](@ref).
(Note changed keyword argument names.)
"""
function rfc_mail(; from=missing, to=String[], cc=String[], bcc=String[], subject, content,
                  replyto="",
                  message_id = "",
                  in_reply_to="",
                  references="",
                  date = now(),
                  keywords = String[], kw... )
    from = from === missing ? primary_email(;kw...) : from
    io = SMTPClient.get_body(
        to, from,
        subject,
        content;
        cc=cc,
        bcc=bcc,
        replyto=replyto,
        messageid=message_id,
        inreplyto=in_reply_to,
        references=references,
        date=date,
        keywords=keywords,
        kw...
    )
    s = String(take!(io))
end

function rfc_mail(subject::AbstractString, content::AbstractString="";
                  from=missing, to=String[], cc=String[], bcc=String[],
                  replyto="",
                  message_id = "",
                  in_reply_to="",
                  references="",
                  date = now(),
                  keywords = String[], kw... )
    from = from === missing ? primary_email(;kw...) : from
    io = SMTPClient.get_body(
        to, from,
        subject,
        SMTPClient.PlainContent(content);
        cc=cc,
        bcc=bcc,
        replyto=replyto,
        messageid=message_id,
        inreplyto=in_reply_to,
        references=references,
        date=date,
        keywords=keywords,
        kw...
    )
    s = String(take!(io))
end


_tagflag(x::TagChange) = x.prefix * replace(x.tag, " " => "%20")
_tagflag(x::AbstractString) = x
_tagflags(v::AbstractVector) = map(_tagflag, v)

export escape_id
"""
    escape_id(id::AbstractString) -> String

Ensure message-id is wrapped in angle brackets for notmuch id: queries.
If already wrapped, returns as-is.
"""
escape_id(id::AbstractString) = begin
    s = strip(id)
    (startswith(s, "<") && endswith(s, ">")) ? s : "<" * s * ">"
end

"""
    notmuch_insert(mail; folder="juliatest")

Insert `mail` as a mail file into `notmuch` (see `notmuch insert`).
Writes a file and changes tags in xapian.
"""
function notmuch_insert(mail; tag = TagChange[], folder="Draft", kw...)
    tgs = tag isa AbstractVector ? _tagflags(tag) : [_tagflag(tag)]
    open(
        notmuch_cmd("insert", "--create-folder", "--folder=$folder", tgs...; kw...),
        "w", stdout,
    ) do io
        println(io, mail)
    end
end

export notmuch_insert

_toarg(x) = x
_toarg(x::Query) = render(x)

# Overloads to accept Query
notmuch_count(q::Query, x...; kw...) = notmuch_count(_toarg(q), map(_toarg, x)...; kw...)
notmuch_search(q::Query, x...; offset=0, limit=LIMIT, kw...) =
    notmuch_search(_toarg(q), map(_toarg, x)...; offset, limit, kw...)
notmuch_show(q::Query, x...; kw...) =
    notmuch_show(_toarg(q), map(_toarg, x)...; kw...)
notmuch_ids(q::Query; limit=missing, kw...) = notmuch_ids(_toarg(q); limit, kw...)

function replies(id)
    notmuch_search
end

include("Telegram.jl")
include("gmi.jl")

query(x::AbstractString) = query_parser(x; trace=true)

include("setup.jl")

using SMTPClient
include("msmtp.jl")
include("outbox.jl")
# Make Outbox symbols available at top-level
using .Outbox: SMTPSettings, smtp_settings_map, queue_mail, outbox_ids, send_outbox

# Function to be called when the module is loaded
function __init__()

    
    # sm = summary("tag:inbox and not $blacklist")
    # f = DataFrame(sm.from)
    # sort!(f,:count)
    # println(f)
    
    # t = DataFrame(sm.to)
    # sort!(t,:count)
    # println(t)
    
    # println("users:", join(usernames(),", "))
    # println("\nconfigured smtp mail adresses:\n  ",
    #         join(my_mails,"\n  "))
    # offlimapcfg = offlineimap_config()
    # println("\nConfigured offlineimap accounts:")
    # #println(offlimapcfg)
    # println(DataFrame([
    #     try
    #         lcl = offlimapcfg[Symbol("Account $e")][:localrepository]
    #         rmt = offlimapcfg[Symbol("Account $e")][:remoterepository]
    #         lclr = offlimapcfg[Symbol("Repository $lcl")]
    #         rmtr = offlimapcfg[Symbol("Repository $rmt")]
            
    #         (name = e,
    #          folder = lclr[:localfolders],
    #          user = rmtr[:remoteuser],
    #          host = rmtr[:remotehost]                    )
    #     catch err
    #         printstyled("offlineimap $e not set up correctly $err";color=:red)
    #         (name = e,
    #          folder = "?",
    #          user = "?",
    #          host = "$e"                    )
    #     end
    #     for e in offlimapcfg[:general][:accounts]

    #         ]))
end

"""
    Key = Union{AbstractString,Symbol} 

Genie GET and POST key type.
"""
Key = Union{AbstractString,Symbol}

function main()
  Core.eval(Main, :(const UserApp = $(@__MODULE__)))

  Genie.genie(; context = @__MODULE__)

  Core.eval(Main, :(const Genie = UserApp.Genie))
  Core.eval(Main, :(using Genie))
end

include("genie.jl")
#include("llm.jl")
include("isless.jl")
struct Selection
    query::Query
    head::Any
    count::Int
    subsets::Dict{Query,Any}
    function Selection(q::AbstractString; kw...)
        qp = query_parser(q; trace=true)
        N = notmuch_count(q; kw...)
        head = notmuch_tree(Emails, q; kw...)
        subq = unique(Notmuch.pushq!(Notmuch.Query[],head))
        new(qp, head, N, Dict{Query,Any}([sq => (notmuch_count(sq; kw...),
                                                 notmuch_count(and_query(qp, sq); kw...))
                                                 
                                                 
                                          for sq in subq ]))
    end
end

struct Window{T}
    value::T
    query::Query
    offset::Int
    limit::Int
    count::Union{Missing,Int}
end

function pushq!(x::Vector{Query}, sq::AbstractVector)
    for e in sq
        pushq!(x, e)
    end
    x
end

function pushq!(x::Vector{Query}, sq::WithReplies)
    pushq!(x, sq.message)
    pushq!(x, sq.replies)
    x
end
pushq!(x::Vector{Query}, sq::Query) = push!(x,sq)
function pushq!(x::Vector{Query}, sq::Email)
    pushq!(x, fromto(email_parser(sq.headers.From).email))
    for t in recipients_parser(sq.headers.Cc, trace=true)
        pushq!(x, fromto(t.email))
    end
    for t in recipients_parser(sq.headers.To, trace=true)
        pushq!(x, fromto(t.email))
    end
    for t in sq.tags
        pushq!(x, tag(t))
    end
    x
end
fromto(x) = NotmuchLeaf{:fromto}(x)
tag(x) = NotmuchLeaf{:tag}(x)
pushq!(x::Vector{Query}, sq::Nothing) = x

subqueries(x::AbstractVector, subsets; scope) = subsets

function Base.show(io::IO, x::Selection)
    println(io, x.query,"     has ", x.count, " emails.")
    println(io, x.head)
    ##println(io, DataFrame(sort([ (query = q, count = N) for (q,N) in pairs(x.subsets) ],by=x->x.count)))
    for (q,N) in sort(collect(pairs(x.subsets)),by=x->x[2])
        println(io, N, " <= ", q)
    end
end

using ReplMaker
function parse_to_query(x)
    quote Notmuch.Selection($x) end
end

initrepl() =
    ReplMaker.initrepl(
        parse_to_query, 
        prompt_text="notmuch> ",
        prompt_color = :red, 
        start_key='~', 
        mode_name="notmuch_mode")



end
