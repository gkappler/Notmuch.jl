"""
    Notmuch.jl

is a julia wrapper for [notmuch mail](https://notmuchmail.org/) indexer (that supports arbitrary tags and advanced search).
Notmuch mail indexes emails into a xapian database.
Emails need to be stored in maildir standard.

- maildir can be smoothly synchronized with an IMAP server by [offlineimap](http://www.offlineimap.org/).
- maildir is an archiving standard for email datasets. `Notmuch.jl` opens such email data up for analyses in Julia.

On linux with a `notmuch` setup your user mails are searched by default.
Keyword argument `user` switches the `maildir` (and database) to
`joinpath(ENV["NOTMUCHJL"],"home")`.
"""
module Notmuch
using JSON3
Key = Union{AbstractString,Symbol} 
using Genie, Logging, LoggingExtras

function main()
  Core.eval(Main, :(const UserApp = $(@__MODULE__)))

  Genie.genie(; context = @__MODULE__)

  Core.eval(Main, :(const Genie = UserApp.Genie))
  Core.eval(Main, :(using Genie))
end

export notmuch_json, notmuch_search, notmuch_tree, notmuch_count, notmuch_cmd

checkdir(x) = !isdir(x) && mkdir(x)

"""
    userENV(; workdir= get(ENV,"NOTMUCHJL",pwd()), homes = joinpath(workdir, "home"), user = nothing)

Construct environment `Dict("HOME" => joinpath(homes,user), "MAILDIR" => joinpath(homes,user,"maildir"))`.

If `user === nothing` use 
`Dict("HOME" => get(ENV,"NOHOME",ENV["HOME"]), "MAILDIR" => get(ENV,"NOMAILDIR", ENV["MAILDIR"]))`.

See [`notmuch_cmd`](@ref), [`offlineimap!`](@ref), and [`msmtp_runqueue!`](@ref)
"""
function userENV(; workdir= get(ENV,"NOTMUCHJL",pwd())
                 , homes = joinpath(workdir, "home")
                 , user = nothing)
    ## @show user
    if user === nothing || user == ""
        Dict("HOME" => get(ENV,"NOHOME",ENV["HOME"]) # ENV["NOTMUCHJL_HOME"]
             , "MAILDIR" => get(ENV,"NOMAILDIR", ENV["MAILDIR"]))
    else
        Dict("HOME" => joinpath(homes,user)
             , "MAILDIR" => joinpath(homes,user,"maildir"))
    end
end

# function noENV!(; workdir= get(ENV,"NOTMUCHJL",pwd()))
#     paths = (workdir = workdir
#              , home = ENV["NOHOME"] # ENV["NOTMUCHJL_HOME"]
#              , maildir = ENV["NOMAILDIR"])
#     ENV["HOME"] = paths.home
#     ENV["MAILDIR"] = paths.maildir
#     cd(paths.workdir)
#     paths
# end

export offlineimap!

"""
    offlineimap!(; cfg = ".offlineimaprc", kw...)

Run system Cmd `offlineimap` and then [`notmuch_new`](@ref).
Returns output of both.

For user `kw...` see [`userENV`](@ref).
"""
function offlineimap!(; cfg = ".offlineimaprc", kw...)
    env = userENV(; kw...)
    #cd(@show paths.home)
    # @debug "offlineimap" cfg
    r = try
        read(Cmd(`offlineimap -c $cfg`; dir = env["HOME"], env=env), String)
    catch e
        @error "offlineimap error" e
    end
    rnew = read(notmuch_cmd("new"; kw...),String)
    ##noENV!()
    (offlineimap = r, notmuch_new = rnew)
end

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


"""
    notmuch_cmd(command, x...; user=nothing)

Command with `env=`[`userENV`](@ref), and `dir=env["HOME"]`.

!!! note
    running the command as a different user (`user !== nothing`) 
    is untested:
    `sudo -u \$user -i ...`
"""
function notmuch_cmd(command, x...; log=false, kw...)
    env = userENV(; kw...) ## ??
    # cd(paths.home)
    cfg = ".notmuch-config"
    y = [x...]
    ##c = if user===nothing
    c = Cmd(`/usr/bin/notmuch --config=$cfg $command $y`,
            env=env,
            dir=env["HOME"])
    ##else
    ##    `sudo -u $user -i /usr/bin/notmuch $command $y`
    ##endo
    log && @info "notmuch cmd" c
    c
end

"""
    notmuch(x...; kw...)

Run [`notmuch_cmd`](@ref) and return output as `String`.

See [`notmuch_json`](@ref)
To get json as a String, provide `"--format=json"` as argument.

For user `kw...` see [`userENV`](@ref).
"""
function notmuch(x...; kw...)
    r = try
        read(notmuch_cmd(x...; kw...), String)
    catch e
        @error "notmuch error" e
    end
    ##noENV!()
    r
end


"""
    notmuch_json(command,x...; kw...)

Parse [`notmuch`](@ref) with `JSON3.read`.

For user `kw...` see [`userENV`](@ref).
"""
function notmuch_json(command,x...; kw...) 
    r = notmuch(command, "--format=json", x...; kw...)
    r === nothing && return nothing
    JSON3.read(r)
end

function notmuch_count(x...; kw...)
    c = notmuch("count", x...; kw...)
    c === nothing && return nothing
    parse(Int,chomp(c))
end

include("Threads.jl")

ToF = Union{Type,Function}

"""
    notmuch_search(query, x...; offset=0, limit=5, kw...)
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

using Dates
function date_query(from,to)
    function unixstring(x)
        convert(Int64,round(datetime2unix(round(x, Second))))
    end
    "date:@$(unixstring(from))..@$(unixstring(to))"
end

function count_timespan(q, a...; kw...)
    function query_timestamp(q, b...)
        ns = notmuch_search(Thread,q,b...; limit=1, kw...)
        ##@info "q" q b ns[1].timestamp
        ##dump(ns[1])
        ns[1].timestamp
    end
    c = notmuch_count(q, a...; kw...)
    c == 0 && return nothing
    (
        from = query_timestamp(q,"--sort=oldest-first"),
        to = query_timestamp(q,"--sort=newest-first"),
        count = c
    )
end

function binary_search(monotoneinc::Function, query; lt=<, low, high, eps=0.001, maxiter = 1000)
    middle(l, h) = round(Int, (l + h)//2)
    iter = 0
    ##@info "bins" low high
    while low <= high && iter < maxiter
        mid = middle(low, high)
        midv = monotoneinc(mid)
        if lt(midv, query-eps)
            low = mid
        elseif lt(midv, query+eps)
            return mid
        else
            high = mid
        end
        iter = iter + 1
    end
    low 
end

function time_counts(q, a...; target=1000, eps = 10, maxiter = 10, kw...)
    span = count_timespan(q, a...; kw...)
    to = span.to
    from = span.from
    r = [span]
    ##@info "?" to from 
    opt = binary_search(
        target; low = Dates.value(to-to)
        , high = Dates.value(to-from)
        , eps=eps
        , maxiter = maxiter) do delta
            neu = notmuch_count("($q) and ($(date_query(to-Millisecond(delta),to)))", a...; kw...)
            push!(r, (from=to-Millisecond(delta), to=to, count = neu))
            neu
        end

    (probes = r
     , from = to-Millisecond(opt), to = to)
end
                  

function time_counts_(q, a...; target=1000, kw...)
    span = count_timespan(q, a...; kw...)
    r = [span]
    # Ziel: reduziere data.grundgehalt solange bis 
    # arbeitgeberkosten_iteration == arbeitgeberkosten_aktuell
    query = target
    to = span.to
    from = span.from
    let days = Dates.value(to-from), doopt = true, eps = 1, low = Dates.value(to-to), high = Dates.value(to-from)
        @info "binary search optimierung" days to  
        while doopt
            @show neu = notmuch_count(@show "($q) and ($(date_query(to-Millisecond(days),to)))", a...; kw...)
            queryneu = neu
            push!(r, (from=to-Millisecond(days), to=to, count=neu))
            if queryneu - query > eps # teurer geworden, grundgehalt adaptiv reduzieren 
                @debug " $(days/1000/60/60/24) verringern"
                high = days
                days = (days + low / 2.0)
            elseif queryneu - query < -eps
                @debug " $(days/1000/60/60/24) erhöhen"
                low = days
                days = ( days + high ) / 2
            else
                doopt = false
            end
            #altgrundgehalt = neu.grundgehalt
        end
    end
    r
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
        tc = time_counts(q; target=target, kw... ).probes
        span=tc[end]
        from = span.from
        to = span.to
        timec = date_query(from,to)
        q_ = "($q) and ($timec)"
        (timespan_counts = tc
         , address = notmuch_json( :address, a...,  q_; kw..., log=true))
    else
        (timespan_counts = []
         , address = notmuch_json( :address, a...,  q; kw..., log=true))
    end
end
export notmuch_address


"""
    notmuch_show(query, x...; body = true, entire_thread=false, kw...)
    notmuch_show(T::Union{Type,Function}, x...; kw...)

Return `notmuch show`.

With first argument `f::Union{Type,Function}` each result is converted with calling `f`, otherwise JSON is returned.

For user `kw...` see [`userENV`](@ref).
"""
function notmuch_show(query, x...; body = true, entire_thread=false, kw...)
    tids = [ t.thread for t in notmuch_search(query, x...; kw...) ]
    ##@debuginfo "show" query x tids
    threadq = join("thread:" .* tids, " or ")
    notmuch_json(:show, x..., "--body=$body", "--entire-thread=$(entire_thread)",
                 "($query) and ($threadq)"; kw...)
end
    
notmuch_show(T::ToF, x...; kw...) = T(notmuch_show(x...; kw...))
export notmuch_show

"""
    notmuch_tree(x...; body = false, entire_thread=false, kw...)
    notmuch_tree(T::ToF, x...; kw...)

Parsimonous tree query for fetching structure, convenience query for 
[`notmuch_show`](@ref)

With first argument `f::Union{Type,Function}` each result is converted with calling `f`, otherwise JSON is returned.

For user `kw...` see [`userENV`](@ref).
"""
notmuch_tree(x...; body = false, entire_thread=false, kw...) =
    notmuch_show(x...; body = body, entire_thread=entire_thread, kw...)
notmuch_tree(T::ToF, x...; kw...) = T(notmuch_tree(x...; kw...))
export notmuch_tree




export TagChange, notmuch_tag
"""
    TagChange(prefix, tag)

Prefix is either "+" or "-".
"""
struct TagChange
    prefix::String
    tag::String
    function TagChange(prefix, tag)
        @assert prefix in ["+","-"]
        new(prefix,tag)
    end
end
function TagChange(tag)
    TagChange(tag[1:1], tag[2:end])
end

Base.show(io::IO, x::TagChange) =
    print(io, x.prefix, x.tag)

"""
    notmuch_tag(batch::Vector{Pair{String,TagChange}}; kw...)

Tag `query => tagchange` entries in `batch` mode.

Spaces in tags are supported, but other query string encodings for [`notmuch tag`](https://manpages.ubuntu.com/manpages//bionic/man1/notmuch-tag.1.html) are not.

For user `kw...` see [`userENV`](@ref).
"""
function notmuch_tag(batch::Vector{Pair{String,TagChange}}; kw...)
    ##cd(@show paths.home)
    open(
        Notmuch.notmuch_cmd(
            "tag", "--batch"; kw...
        ),
        "w", stdout) do io
            for (q, tc) in batch
                @debug "tag $q" tc
                # println(tc.prefix,
                #         replace(tc.tag, " " => "%20")
                #         , " -- ", q)
                println(io, tc.prefix,
                        replace(tc.tag, " " => "%20")
                        , " -- ", q)
            end
            # close(io)
        end
    ##noENV!()
end
notmuch_tag(batch::Pair{<:AbstractString,<:AbstractString}...; kw...) =
    notmuch_tag([q => TagChange(x) for (q,x) in batch]; kw...)



using SMTPClient

function mailfile(; from, to=String[], cc=String[], bcc=String[], subject, body, replyto="", messageid="", in_reply_to="", references="", date = now(), attachments = String[], tags = String[], message_id = "", inreplyto ="", kw... )
    ts = [ "#$tag" for tag in tags
              if !(tag in ["inbox", "unread", "new", "flagged","draft","draftversion","attachment"])]
    io = SMTPClient.get_body(
        to, from,
        subject * ( isempty(ts) ? "" : "   " * join(ts, " ")),
        body; cc=cc,
        bcc=bcc,
        replyto=replyto,
        messageid=messageid,
        inreplyto=inreplyto,
        references=references,
        date=date,
        ## attachments file upload mechanism?
        # save in attachments/:mailfilename/uploadfilen.ame
        attachments=attachments
    )
    s = String(take!(io))
end
export mailfile

"""
    notmuch_insert(mail; folder="juliatest")

Insert `mail` as a mail file into `notmuch` (see `notmuch insert`).
Writes a file and changes tags in xapian.
"""
function notmuch_insert(mail; tags = ["new"], folder="elmail", kw...)
    open(
        Notmuch.notmuch_cmd(
            "insert", "--create-folder" ,"--folder=$folder",
            "-new",
            ["+"*p for p in tags]...;
            kw...
                ),
        "w", stdout) do io
            println(io,mail)
        end
end
export notmuch_insert


include("Show.jl")

include("msmtp.jl")

end
