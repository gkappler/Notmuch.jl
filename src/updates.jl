export TagChange, FolderChange

RuleHistory = Dict{Tuple{Any,Query},Vector{Pair{Int,Union{Nothing,Email}}}}

function Base.show(io::IO, x::RuleHistory)
    for (change, q) in sort(collect(keys(x)))
        println(io, "\n", change, "  <=  ", q )
        events = x[(change, q)]
        for (n,e) in events
            print(io, " | ", n, " ", e.headers.Date)
        end
    end
end

@auto_hash_equals struct FolderChange
    from_folder::String
    to_folder::String
end
function Base.show(io::IO, x::FolderChange)
    print(io, styled"mv {underline:{grey:$(x.from_folder)}} {inverse:{black:$(x.to_folder)}}")
end
query(x::FolderChange) =
    NotmuchLeaf{:folder}(x.from_folder)


export @rule_str
macro rule_str(x)
    #esc(quote
        MailsRule(x)
    #end)
end

export MailsRule
@auto_hash_equals struct MailsRule{C}
    change::C
    count::Union{Int, Missing}
    query::Query
    #mailid::Union{String, Missing}
    MailsRule(change, query) =
        new{typeof(change)}(change, missing, query)
    MailsRule(change, count::Union{Int,Missing}, query) =
        new{typeof(change)}(change, count, query)
end

MailsRule(rule::AbstractVector) =
    length(rule) == 1 ? rule[1] : [ MailsRule(r) for r in rule ]

MailsRule(rule::AbstractString) =
    rule_parser(rule; trace=true)

query(x::MailsRule) =
    and_query(query(x.change), x.query)
Base.convert(::Type{Query}, x::String) = query_parser(x)
function Base.show(io::IO, x::MailsRule)
    print(io, x.change, " ", x.count, " ", x.query)
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


function ynp(x)
    println(x,"?")
    if readline(stdin) in ["y", "yes"]
        true
    else
        false
    end
end
const MAILDIR_SUBS = ("cur","new","tmp")

"""
    ensure_maildir!(folder::AbstractString) -> Bool

Ensure standard Maildir subdirectories exist under `folder`’s parent.
Returns true if ready to move into `joinpath(folder)`.
Throws on non-standard suffix.
"""
function ensure_maildir!(target_folder::AbstractString)
    sub = basename(target_folder)
    sub in MAILDIR_SUBS || error("Target '$target_folder' must end with cur/new/tmp")
    root = dirname(target_folder)
    for s in MAILDIR_SUBS
        mkpath(joinpath(root, s))
    end
    isdir(target_folder) || error("Failed to create '$target_folder'")
    return true
end

export apply_rule
apply_rule(r; kw...) = apply_rule(r, "$r"; kw...)

apply_rule(r::AbstractVector, a...; kw...) =
    [ apply_rule(e, a...; kw...)
      for e in r ]

function apply_rule(x::MailsRule{FolderChange}, in_reply_to; do_mkdir_prompt::Function=msg -> begin
                        @info msg
                        true
                    end, kw...)
    function perform_mv(f, target_folder; revertio)
        fname = basename(f); dname = dirname(f)
        ensure_maildir!(target_folder)
        target_file = joinpath(target_folder, fname)
        mv(f, target_file; force=true)
        println(revertio, "mv $target_file $dname")
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
        @info mv_summary
        ##notmuch_tag(x.query => x.change; kw...)
        rfc = rfc_mail(
            from = "mvrule@notmuch.jl",
            #to = to, 
            subject = "$(x.change) $(length(ids)) $(x.query)", 
            in_reply_to = in_reply_to,
            content = 
                MultiPart(
                    :mixed,
                    SMTPClient.PlainContent(mv_summary * String(take!(body))),
                    SMTPClient.MIMEContent(
                        "revert-mv.sh",
                        ## 
                        String(take!(attach))
                    )
                )
        )
        ##println(rfc)
        notmuch_insert(
            rfc;
            folder = "notmuch_rule/mv",
            tag = tag"+rule/mv -inbox -new",
            kw...
                )
        notmuch(:new; kw...)
        ids
    else
        []
    end
end

## Todo: in practice this should at
apply_rule(x::MailsRule{<:AbstractVector}, a...; kw...) =
   vcat( [ apply_rule(MailsRule(tc,x.count,x.query), a...; kw...)
      for tc in x.change ]...)

function apply_rule(x::MailsRule{<:Function}, in_reply_to; kw...)
    q = x.query
    affected = notmuch_count(q; kw...)
    if affected > 0
        ids = notmuch_ids(q; kw...)
        rfc = x.change(ids)
        ids
    else
        []
    end
end

    


function apply_rule(x::MailsRule{TagChange}, in_reply_to; kw...)
    q = query(x)
    affected = notmuch_count(q; kw...)
    if affected > 0
        ids = notmuch_ids(q; kw...)
        notmuch_tag(x.query => x.change; kw...)
        rfc = rfc_mail(
            from = "tagrule@notmuch.jl",
            #to = to, 
            subject = "$(x.change) tag $(length(ids)) $(x.query)", 
            in_reply_to = in_reply_to,
            content = 
                MultiPart(
                    :mixed,
                    SMTPClient.PlainContent(""),
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
            tag = tag"+rule/tag -inbox -new",
            kw...
        )
        ids
    else
        []
    end
end


# function tag_new(q="from:targrule@notmuch.jl"; user=nothing, pars...)
#     rule_history(q; pars...)
#     for r in rule_history(q; pars...)
#         tagrule = r.first
#         queries = r.second
#         for (query, history) in pairs(queries)
#             if length(history)>1
#                 println("archiving history ($(length(history)))")
#                 for h in history[2:end]
#                     notmuch_tag("id:" * h.id => "-autotag")
#                 end
#             end
#             push!(get!(tcs, query) do
#                       TagChange[]
#                   end,
#                   MailTagChange(tagrule, history[1].id)
#                   )
#         end
#     end
#     R = notmuch_tag(tcs; user = user, body = "")
# end


function apply_rules(q="from:notmuch.jl"; pars...)
    local rh = rule_history(q; pars...)
    local count = 0
    for ((rule, query), history) in rh
        local rule_count = 0
        #println(rule)
        #println(history)
        #@info "rule" rule history
        local N, email = history[1]
        local current_run = apply_rule(MailsRule(rule,N,query), email.id; pars...)
        empty!(history)
        pushfirst!(history, length(current_run) => nothing)
        rule_count += length(current_run)
        count += length(rule_count)
    end
    rh
end




function rule_history_old(q="from:notmuch.jl"; remove_errors=true, kw...)
    history = [ Email(x; body=false) for x in notmuch_ids(q; kw...)  ]
    @info "history of $(length(history)) matching $q"
    tcs = Dict()
    for (email) in history
        r = MailsRule(email.headers.Subject)
        if r.count > 0
            rd = get!(
                get!(tcs, r.change) do
                    Dict()
                end,
                r.query) do
                    []
                end
            push!(rd, r.count => email )
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


add_rule!(tcs, r::AbstractVector, email) =
    for e in r
        add_rule!(tcs, e, email)
    end
        

add_rule!(tcs, r, email) =
    if r.count > 0
        rd = get!(tcs, (r.change, r.query)) do
            []
        end
        push!(rd, r.count => email )
    else
    end

function rule_history(q="from:notmuch.jl"; remove_errors=true, kw...)
    history = [ Email(x; body=false) for x in notmuch_ids(q; kw...)  ]
    @info "history of $(length(history)) matching $q"
    tcs = RuleHistory()
    for (email) in history
        try 
            r = MailsRule(email.headers.Subject)
            add_rule!(tcs, r, email)
        catch err
            @warn "unknown rule history email $err" email
            for f in email.filename
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





"""
    notmuch_tag(batch::Pair{<:AbstractString,<:AbstractString}...; kw...)
    notmuch_tag(batch::Vector{Pair{String,TagChange}}; kw...)

Tag `query => tagchange` entries in `batch` mode.

Spaces in tags are supported, but other query string encodings for [`notmuch tag`](https://manpages.ubuntu.com/manpages//bionic/man1/notmuch-tag.1.html) are currently not.

For user `kw...` see [`userENV`](@ref).
"""
# function log_notmuch_tag(batch::Dict{<:AbstractString,<:AbstractVector{TagChange}};
#                      user = nothing,
#                      dryrun = false,
#                      from= userEmail(user), to = String["elmail_api_tag@g-kappler.de"],
#                      body = nothing,
#                      kw...)
#     1
#     freshtags = Any[]
#     for (qq,tagchanges) in batch
#         for tc in tagchanges
#             q = "("*qq*") and (" * (tc.rule.prefix == "+" ? " not tag:" * tc.rule.tag : " tag:" * tc.rule.tag )  * ")"
#             ids = notmuch_ids(q; user = user, kw...)
#             log_mail = if body === nothing
#                 ids -> nothing
#             else 
#                 ids -> if length(ids)==1
#                     (folder = "elmail/tag", tags = [ TagChange("+tag") ], 
#                      rfc_mail = rfc_mail(from = from, to = to, 
#                                          in_reply_to = "<" * ids[1] * ">",
#                                          subject = "$tc tag", content= SMTPClient.PlainContent(body)))
#                 else
#                     (folder = "elmail/autotag", tags = [ TagChange("+autotag") ],
#                      rfc_mail = rfc_mail(
#                          from = from, to = to, 
#                          subject = "$tc tag $(length(ids)) $qq", 
#                          in_reply_to = if in_reply_to === nothing
#                              ""
#                          else
#                              "<$(tc.mailid)>"
#                          end,
#                          content = 
#                              MultiPart(
#                                  :mixed,
#                                  SMTPClient.PlainContent(body),
#                                  SMTPClient.MIMEContent(
#                                      "notmuch.ids",
#                                      ## 
#                                      join([tc.rule.prefix *
#                                          replace(
#                                              tc.rule.tag,
#                                              " " => "%20") *
#                                                  " -- id:" * id
#                                            for id in ids ]
#                                           ,"\n")
#                                  )
#                              )
#                      ))
#                 end
#             end
#             insert = log_mail(ids)
#             #println(rfc)
#             !isempty(ids) && if insert !== nothing
#                 @info "tag $(length(ids)) $q => $tc, log ids"
#                 notmuch_insert(insert.rfc_mail
#                                ; tags = [ insert.tags..., TagChange("-inbox"), TagChange("-new") ]
#                                , folder= insert.folder
#                                , user = user, kw...
#                                    )
#             else
#                 @info "tag $(length(ids)) $q => $tc"
#             end
#             push!(freshtags,(rule = qq => tc, count = length(ids)))
#         end
#     end
#     ##cd(@show paths.home)
#     dryrun || open(
#         Notmuch.notmuch_cmd(
#             "tag", "--batch"; user = user, kw...
#         ),
#         "w", stdout) do io
#             for (q, tagchanges) in batch
#                 # @info "tag $q" tagchanges
#                 # println(tc.rule.prefix,
#                 #         replace(tc.rule.tag, " " => "%20")
#                 #         , " -- ", q)
#                 for tc in tagchanges
#                     println(io, tc.rule.prefix,
#                             replace(tc.rule.tag, " " => "%20")
#                             , " -- ", q)
#                 end
#             end
#             # close(io)
#         end
#     freshtags
#     ##noENV!()
# end
