export TagChange, FolderChange

export @rule_str
macro rule_str(x)
    quote
        MailsRule($x)
    end
end

struct MailsRule{C}
    change::C
    count::Union{Int, Missing}
    query::Query
    mailid::Union{String, Missing}
    MailsRule(change, query) =
        new{typeof(change)}(change, missing, query, missing)
    MailsRule(change, count::Int, query) =
        new{typeof(change)}(change, count, query, missing)
    MailsRule(change, query, mailid) =
        new{typeof(change)}(change, missing, query, mailid)
end
MailsRule(rule::AbstractString) =
    rule_parser(rule)
query(x::MailsRule) =
    and_query(query(x.change), x.query)

function Base.show(io::IO, x::MailsRule)
    print(io, x.change, " ", x.count, " ", x.query)
end

export apply_rule
function apply_rule(x::MailsRule{<:AbstractVector}; kw...)
    for c in x.change
        apply_rule(MailsRule(c,x.query,x.mailid); kw...)
    end
end
function maildir_names(f, mdir=missing; kw...)
    mdir = mdir === missing ? maildir(;kw...) : mdir
    dir = dirname(f)
    maildirstate = basename(dir)
    dir = dirname(dir)
    @assert maildirstate in ["cur","tmp","new"]
    @assert startswith(dir, mdir)
    (
        dir = dir[nextind(dir, lastindex(mdir), 2):end],
        state = maildirstate,
        filename = basename(f)
     )
end
function apply_rule(x::MailsRule{FolderChange}; kw...)
    function perform_mv(f, target_folder; revertio)
        fname=basename(f)
        dname=dirname(f)
        target_file = if isdir(target_folder)
            joinpath(target_folder,fname)
        else
            target_folder
        end
        mv(f,target_file)
        println(revertio,"mv $target_file $dname")
    end
    mdir=maildir(;kw...)
    q = query(x)
    affected = notmuch_count(q; kw...)
    if affected > 0
        ids = notmuch_ids(q; kw...)
        emails = [ Email(id) for id in ids ]
        body = IOBuffer()
        ##print_summary(body, q; kw...)
        attach  = IOBuffer()

        files = Dict{Tuple{String,String},Int}()
        for e in emails
            println(body, e,"\n")
            for f in e.filename
                maildir_file = maildir_names(f)
                if maildir_file.dir == x.change.from_folder
                    target_folder = joinpath(x.change.to_folder, maildir_file.state)
                    perform_mv(f, joinpath(mdir, target_folder); revertio=attach)
                    key = (joinpath(maildir_file.dir,
                                    maildir_file.state),
                           target_folder)
                    files[key] = get(files, key, 0) + 1
                else
                end
            end
        end
        mv_summary = "Moved\n" * join(["$N mail files $from_folder => $target_folder"
                                                                    for ((from_folder, target_folder), N) in pairs(files)],
                                                                   "\n") *"\n within maildir $mdir\n\n\n\nMails:\n"
        
        ##notmuch_tag(x.query => x.change; kw...)
        rfc = rfc_mail(
            from = "mvrule@notmuch.jl",
            #to = to, 
            subject = "$(x.change) $(length(ids)) $(x.query)", 
            in_reply_to = x.mailid,
            content = 
                MultiPart(
                    :mixed,
                    SMTPClient.Plain(mv_summary * String(take!(body))),
                    SMTPClient.MIMEContent(
                        "revert-mv.sh",
                        ## 
                        String(take!(attach))
                    )
                )
        )
        println(rfc)
        notmuch_insert(
            rfc;
            folder = "notmuch_rule/mv",
            tags = tag"+rule/mv",
            kw...
                )
        notmuch_new()
    else
    end
end

function apply_rule(x::MailsRule{TagChange}; kw...)
    q = query(x)
    @show affected = notmuch_count(q; kw...)
    if affected > 0
        ids = notmuch_ids(q; kw...)
        notmuch_tag(x.query => x.change; kw...)
        rfc = rfc_mail(
            from = "tagrule@notmuch.jl",
            #to = to, 
            subject = "$(x.change) tag $(length(ids)) $(x.query)", 
            in_reply_to = x.mailid,
            content = 
                MultiPart(
                    :mixed,
                    SMTPClient.Plain(""),
                    SMTPClient.MIMEContent(
                        "revert-notmuch.ids",
                        ## 
                        join([(x.change.prefix == "+" ? "-" : "+") *
                            replace(x.change.tag, " " => "%20") *
                            " -- id:" * id
                              for id in ids ]
                             ,"\n")
                    )
                )
        )
        notmuch_insert(
            rfc;
            folder = "notmuch_rule/tag",
            tags = tag"+rule/tag",
            kw...
        )
    else
    end
end


function log_changes(change::TagChange, ids)
end

# struct MailTagChange
#     rule::TagChange
#     mailid::Union{String, Nothing}
# end

# Base.show(io::IO, x::MailTagChange) =
#     print(io,x.rule)

# @with_kw struct LogMail
#     folder::String
#     tags::Vector{TagChange}
#     rfc_mail::String
# end

# Base.convert(::Type{TagChange}, x::MailTagChange) =
#     x.rule





struct FolderChange
    from_folder::String
    to_folder::String
end
function Base.show(io::IO, x::FolderChange)
    print(io, styled"mv {yellow:$(x.from_folder)} {green:$(x.to_folder)}")
end

query(x::FolderChange) =
    NotmuchLeaf{:folder}(x.from_folder)





function tag_new(q="tag:autotag"; user=nothing, pars...)
    tcs = Dict{String, Vector{TagChange}}()
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
                      TagChange[]
                  end,
                  MailTagChange(tagrule, history[1].id)
                  )
        end
    end
    R = notmuch_tag(tcs; user = user, body = "")
    [ r for r in Notmuch.rule_history(q, tag_rule_parser;
                                     pars..., user = user) ]
end


function tagrules(q="tag:autotag", rule_parser=tag_rule_parser; remove_errors=true, kw...)
    history = rule_history(q, rule_parser; kw...)
    tcs = Dict()
    for r in history
        if r.rule.count > 0
            rd = get!(
                get!(tcs, r.rule.change) do
                    Dict()
                end,
                r.rule.query) do
                    []
                end
            push!(rd, (date = r.date, count = r.rule.count, id = r.id, filename=r.filename) )
        else
            @warn "unknown email" r
            for f in r.filename
                if remove_errors
                    trash(f)
                else
                    println("rm $f")
                end
            end
        end
    end
    tcs
end

function rule_history(q="tag:autotag", rule_parser=tag_rule_parser;
                     limit = 1000, kw...)
    [ (;rule = rule_parser(x.headers.Subject),
       date = unix2datetime(x.timestamp),
       id=x.id,
       filename = x.filename,
       tags = x.tags)
      for x in flatten(
          notmuch_show(q
                       ; limit=limit
                       , body = false
                       , kw...))
          ]
end

"""
    notmuch_tag(batch::Pair{<:AbstractString,<:AbstractString}...; kw...)
    notmuch_tag(batch::Vector{Pair{String,TagChange}}; kw...)

Tag `query => tagchange` entries in `batch` mode.

Spaces in tags are supported, but other query string encodings for [`notmuch tag`](https://manpages.ubuntu.com/manpages//bionic/man1/notmuch-tag.1.html) are currently not.

For user `kw...` see [`userENV`](@ref).
"""
function log_notmuch_tag(batch::Dict{<:AbstractString,<:AbstractVector{TagChange}};
                     user = nothing,
                     dryrun = false,
                     from= userEmail(user), to = String["elmail_api_tag@g-kappler.de"],
                     body = nothing,
                     kw...)
    1
    freshtags = Any[]
    for (qq,tagchanges) in batch
        for tc in tagchanges
            q = "("*qq*") and (" * (tc.rule.prefix == "+" ? " not tag:" * tc.rule.tag : " tag:" * tc.rule.tag )  * ")"
            ids = notmuch_ids(q; user = user, kw...)
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
                     rfc_mail = rfc_mail(
                         from = from, to = to, 
                         subject = "$tc tag $(length(ids)) $qq", 
                         in_reply_to = if tc.mailid === nothing
                             ""
                         else
                             "<$(tc.mailid)>"
                         end,
                         content = 
                             MultiPart(
                                 :mixed,
                                 SMTPClient.Plain(body),
                                 SMTPClient.MIMEContent(
                                     "notmuch.ids",
                                     ## 
                                     join([tc.rule.prefix *
                                         replace(
                                             tc.rule.tag,
                                             " " => "%20") *
                                                 " -- id:" * id
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
