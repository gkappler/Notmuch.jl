using Parameters;
    
tags = (IMAP = [ "unread", "new", "flagged","attachment" ]
        , reply = [ "reply", "replied" ]
        , folders = [ "inbox","draft","draftversion", "sent" ]
        , elmail = [ "expanded","todo","done"]
        )

usertags(x) =
    [ tag for tag in x
         if !(tag in vcat(tags...))]



export TagChange, notmuch_tag
"""
    TagChange(prefixtag::AbstractString)
    TagChange(prefix::AbstractString, tag::AbstractString)

Prefix is either "+" for adding or "-" for removing a tag.
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

Base.isequal(x::TagChange, y::TagChange) =
    x.tag == y.tag && x.prefix == y.prefix

Base.isless(x::TagChange, y::TagChange) =
    isless(x.prefix, y.prefix) || (isequal(x.prefix, y.prefix)  && isless(x.tag, y.tag))

function Base.show(io::IO, x::TagChange)
    removed = x.prefix == "-"
    str = if removed
        styled"{:{bright_red:$(x.prefix)$(x.tag)}}{strikethrough:{cyan:}}"
    else
        styled"{bold:{bright_green:$(x.prefix)$(x.tag)}}{cyan:}"
    end
    print(io, str)
end


elmail_api_tag_subject = Either(
    Sequence(Either("+", "-"),
             !Repeat1(CharNotIn(" "))
             , " tag ", integer_base(10),
             " ", !Repeat(AnyChar())) do v
                 (query = v[6]
                  , rule = TagChange(v[1],v[2])
                  , count = v[4])
    end,
    Sequence("Notmuch.MailTagChange(",
             :rule => map(TagChange,!Sequence(Either("+", "-"),!Repeat1(CharNotIn(" ")))),
             ", \"", :id => !Repeat_until(AnyChar(), "\") tag "),
             :count => integer_base(10), " ",
             :query => !Repeat(AnyChar())),
    Sequence("Notmuch.RuleMail2(",
             :rule => map(TagChange,!Sequence(Either("+", "-"),!Repeat1(CharNotIn(" ")))),
             ", \"", :id => !Repeat_until(AnyChar(), "\") tag "),
             :count => integer_base(10), " ",
             :query => !Repeat(AnyChar())),
    map(x-> (subject = x,), !Repeat(AnyChar()))
);

function notmuch_query_parser()
    crit(x) = map(Sequence(x,":", !re"[^ :]+")) do v
        NotmuchLeaf{Symbol(x)}(v[3])
    end
    @with_names atomic_term = Either(CombinedParser[crit(k) for k in ["from", "tag", "to", "id","thread","date","folder" ] ])
    @with_names leaf_term = Either(CombinedParser[
        map(Sequence(re" *not +", atomic_term)) do v
            NotmuchLeaf{:not}(v[2])
        end
        , atomic_term])
    
    ort = map(join(leaf_term, re" +or +")) do v
        or_query(v...)
    end
    term = map(join(ort, re" +and +")) do v
        and_query(v...)
    end
    pushfirst!(atomic_term, with_name(:parenthesis,Sequence(2,re" *\( *",term,re" *\) *")))
           
    Sequence(1,term,AtEnd())
end
struct NotmuchQueryOperator{op}
    subqueries::Vector{Any}
end
struct NotmuchLeaf{op}
    value::Any
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
"""

autotag:
- get history
"""
function tag_history(q="tag:autotag"; limit = 1000, kw...)
    [ (;elmail_api_tag_subject(x.headers.Subject)..., date = unix2datetime(x.timestamp), id=x.id, filename = x.filename, tags = x.tags)
      for x in flatten(notmuch_show(q; limit=limit, body = false, kw...))
          ]
end


isid(x) =
    startswith(x,"id:")

function tagrules(q="tag:autotag"; remove_errors=true, kw...)
    history = tag_history(q; kw...)
    tcs = Dict()
    for r in history
        if r.count > 0
            rd = get!(
                get!(tcs, r.rule) do
                    Dict()
                end,
                r.query) do
                    []
                end
            push!(rd, (date = r.date, count = r.count, id = r.id, filename=r.filename) )
        else
            @warn "unknown email" r
            for f in r.filename
                if remove_errors
                    rm(f)
                else
                    println("rm $f")
                end
            end
        end
    end
    tcs
end

function attachments(x::AbstractVector)
    [ a for a in attachments.(x) if a !== nothing ]
end

function attachments(x::JSON3.Object)
    if hasproperty(x, :body)
        vcat(attachments(x.body)...)
    elseif hasproperty(x, :content)
        if hasproperty(x, Symbol("content-type")) && x["content-type"] in [ "multipart/alternative", "multipart/mixed" ]
            vcat(attachments(x.content)...)
        else
            nothing
        end
    elseif hasproperty(x, Symbol("content-disposition")) && x["content-disposition"] == "attachment"
        x
    elseif hasproperty(x, Symbol("content-type")) && x["content-type"] == "text/html"
        nothing
    else
        @warn ("invalid $x")
        nothing
    end
end

function attachments(id::String; kw...)
    attachments(Notmuch.show(id; body=true, kw...))
end

struct MailTagChange
    rule::TagChange
    mailid::Union{String, Nothing}
end

Base.show(io::IO, x::MailTagChange) =
    print(io,x.rule)

function tag_new(q="tag:autotag"; user=nothing, pars...)
    tcs = Dict{String, Vector{MailTagChange}}()
    for r in tagrules(q; pars..., user = user)
        tagrule = r.first
        queries = r.second
        for (query, history) in pairs(queries)
            if length(history)>1
                println("archiving history ($(length(history)))")
                for h in history[2:end]
                    notmuch_tag("id:" * h.id => "-autotag")
                end
            end
            push!(get!(tcs, query) do
                      MailTagChange[]
                  end,
                  MailTagChange(tagrule, history[1].id)
                  )
        end
    end
    R = notmuch_tag(tcs; user = user, body = "")
    [ r for r in Notmuch.tag_history(; pars..., user = user) ]
end

function message_ids(q; limit = missing, kw...)
    limit = limit === missing ? Notmuch.notmuch_count(q; kw...) : limit
    if limit > 0
            Notmuch.notmuch_search(
                q, "--limit=$limit", "--output=messages";
                limit = limit, kw...)
    else
        []
    end
end

@with_kw struct LogMail
    folder::String
    tags::Vector{TagChange}
    rfc_mail::String
end


Base.convert(::Type{TagChange}, x::MailTagChange) =
    x.rule

export notmuch_tag
"""
    notmuch_tag(batch::Pair{<:AbstractString,<:AbstractString}...; kw...)
    notmuch_tag(batch::Vector{Pair{String,TagChange}}; kw...)

Tag `query => tagchange` entries in `batch` mode.

Spaces in tags are supported, but other query string encodings for [`notmuch tag`](https://manpages.ubuntu.com/manpages//bionic/man1/notmuch-tag.1.html) are currently not.

For user `kw...` see [`userENV`](@ref).
"""
function notmuch_tag(batch::Dict{<:AbstractString,<:AbstractVector{MailTagChange}};
                     user = nothing,#
                     dryrun = false,
                     from= userEmail(user), to = String["elmail_api_tag@g-kappler.de"],
                     body = nothing,
                     kw...)
    1
    freshtags = Any[]
    for (qq,tagchanges) in batch
        for tc in tagchanges
            q = "("*qq*") and (" * (tc.rule.prefix == "+" ? " not tag:" * tc.rule.tag : " tag:" * tc.rule.tag )  * ")"
            ids = message_ids(q; user = user, kw...)
            log_mail = if body === nothing
                ids -> nothing
            else 
                ids -> if length(ids)==1
                    (folder = "elmail/tag", tags = [ TagChange("+tag") ], 
                     rfc_mail = rfc_mail(from = from, to = to, 
                                         in_reply_to = "<" * ids[1] * ">",
                                         subject = "$tc tag", content= SMTPClient.Plain(body)))
                else
                    (folder = "elmail/autotag", tags = [ TagChange("+autotag") ],
                     rfc_mail = rfc_mail(from = from, to = to, 
                                         subject = "$tc tag $(length(ids)) $qq", 
                                         in_reply_to = if tc.mailid === nothing
                                             ""
                                         else
                                             "<$(tc.mailid)>"
                                         end,
                                         content = 
                                             MultiPart(:mixed,
                                                       SMTPClient.Plain(body),
                                                       SMTPClient.MIMEContent(
                                                             "notmuch.ids",
                                                             ## 
                                                             join([tc.rule.prefix * replace(tc.rule.tag, " " => "%20") * " -- id:" * id
                                                                   for id in ids ]
                                                                  ,"\n")
                                                         )
                                                       )
                                         ))
                end
            end
            insert = log_mail(ids)
            #println(rfc)
            !isempty(ids) && if insert !== nothing
                @info "tag $(length(ids)) $q => $tc, log ids"
                notmuch_insert(insert.rfc_mail
                               ; tags = [ insert.tags..., TagChange("-inbox"), TagChange("-new") ]
                               , folder= insert.folder
                               , user = user, kw...
                                   )
            else
                @info "tag $(length(ids)) $q => $tc"
            end
            push!(freshtags,(rule = qq => tc, count = length(ids)))
        end
    end
    
    ##cd(@show paths.home)
    dryrun || open(
        Notmuch.notmuch_cmd(
            "tag", "--batch"; user = user, kw...
        ),
        "w", stdout) do io
            for (q, tagchanges) in batch
                # @info "tag $q" tagchanges
                # println(tc.rule.prefix,
                #         replace(tc.rule.tag, " " => "%20")
                #         , " -- ", q)
                for tc in tagchanges
                    println(io, tc.rule.prefix,
                            replace(tc.rule.tag, " " => "%20")
                            , " -- ", q)
                end
            end
            # close(io)
        end
    freshtags
    ##noENV!()
end
notmuch_tag(batch::Dict{<:AbstractString,<:AbstractSet{TagChange}}; kw...) =
    notmuch_tag(Dict(q => collect(x) for (q,x) in batch); kw...)
notmuch_tag(batch::Pair{<:AbstractString,<:AbstractString}...; kw...) =
    notmuch_tag(Dict(q => [MailTagChange(TagChange(t), nothing) for t in split(x," ")]
                     for (q,x) in batch); kw...)

notmuch_tag(batch::Pair{<:AbstractString,<:TagChange}...; kw...) =
    notmuch_tag(Dict(q => [x] for (q,x) in batch); kw...)
notmuch_tag_from(batch::Pair{<:AbstractString,<:AbstractString}...; kw...) =
    notmuch_tag(Dict("from:$f" => [MailTagChange(TagChange(t), nothing) for t in split(x," ")]
                     for (f,x) in batch); kw...)
    
