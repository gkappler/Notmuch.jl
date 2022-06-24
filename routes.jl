using Pkg
using Genie, Genie.Renderer, Genie.Renderer.Html, Genie.Renderer.Json, SearchLight
using Genie.Requests
using Genie.Responses

using Notmuch



optionstring(x; kw...) =  vcat([ optionstring(e;kw...) for e in pairs(x) ]...)
function optionstring(x::Pair;omit=x->false)
    if omit(x.first)
        optionstring(Val{x.first}(), x.second)
    elseif x.second == ""
        ["--$(x.first)"]
    else
        ["--$(x.first)=$(x.second)"]
    end
end
optionstring(::Val{:q}, x) = [ x ]
optionstring(::Val{:tags}, x) = [ ]

"""
    omitq(x)
    omitqtags(x)

`q` is the query parameter for the search argument in notmuch.

Where it applies (`notmuch tag`) `tags` is the tag flag query `+add` and `-remove`.

Other query parameters are passed as is to `notmuch` as `--setting=value`.
"""
omitq(x) = x == :q
omitqtags(x) = (x == :q) || (x==:tags)


route("/json/" * "count") do 
    payload = getpayload()
    json(parse(Int,chomp(Notmuch.notmuch(
        "count", optionstring(payload, omit = omitq)...;
        user = get(payload,:user,nothing)))))
end

route("/json/" * "tagcount") do 
    payload = getpayload()
    basq = payload[:q]
    ts = Notmuch.notmuch_json(
        "search", "--output=tags",
        optionstring(payload, omit = omitq)...;
        user = get(payload,:user,nothing))
    r = [ (tag=t, count=parse(Int,chomp(
        Notmuch.notmuch(
            "count", "($basq) and tag:$t";
            user = get(payload,:user,nothing)))))
    for t in ts ]
    json(r)
end

route("/json/" * "address") do 
    payload = getpayload()
    json(Notmuch.notmuch_json(
        "address", optionstring(payload, omit = omitq)...;
        user = get(payload,:user,nothing)))
end

route("/json/" * "search") do 
    payload = getpayload()
    json(Notmuch.notmuch_json(
        "search", optionstring(payload, omit = omitq)...;
        user = get(payload,:user,nothing)))
end

route("/json/" * "show") do 
    json(Notmuch.notmuch_json(
        "show", optionstring(payload,
                             omit = omitq)...;
        user = get(payload,:user,nothing)))
end


route("/mimepart") do
    payload = getpayload()
    pars = Notmuch.notmuch_json(
        "show", optionstring(payload, omit = omitq)...;
        user = get(payload,:user,nothing))
    
    Genie.Responses.setheaders(
        "content-type" => pars["content-type"])
    Notmuch.notmuch(
        "show", optionstring(payload, omit = omitq)...;
        user = get(payload,:user,nothing))
end

route("/json/" * "count", method="POST") do
    p = jsonpayload()
    @info "count" p
    basq = get(p,"base-query",nothing)
    ts = p["sub-queries"]
    r = [ parse(Int,chomp(Notmuch.notmuch(
        "count", basq !== nothing ? "($basq) and ($t)" : t;
        user = get(p,"user",nothing))))
          for t in ts ]
    json(r)
end




route("/api/" * "tag", method="POST") do
    payload = jsonpayload()
    @info "tagging" payload
    notmuch_tag(
        [ payload["q"] => TagChange(tc["action"], tc["tag"])
          for tc in payload["tags"]];
        user = get(payload, "user", nothing))
    "ok"
end



route("/json/" * "reply") do 
    payload = getpayload()
    json(Notmuch.notmuch_json(
        "reply", optionstring(payload, omit = omitq)...;
        user = get(payload,:user,nothing)))
end



using SMTPClient

function mailfile(payload; subject = payload["subject"])
    io = SMTPClient.get_body(
        get(payload,"to",String[]),
        payload["from"],
        subject,
        payload["body"];
        cc = get(payload,"cc",String[]),
        bcc = get(payload,"bcc",String[]),
        replyto = get(payload, "replyto", ""),
        messageid=get(payload, "messageid", ""),
        inreplyto= get(payload, "in_reply_to", ""),
        references= get(payload, "references", ""),
        ## attachments file upload mechanism?
        # save in attachments/:mailfilename/uploadfilen.ame
        attachments = get(payload, "attachments", String[])
    )
    s = String(take!(io))
end
    
route("/api/" * "save", method="POST") do
    payload = jsonpayload()
    @info "saving" payload
    open(
        Notmuch.notmuch_cmd(
            "insert", "--create-folder" ,"--folder=elmail",
            "-new",
            ["+"*p for p in payload["tags"]]...;
            user = get(payload, "user", nothing)
        ),
        "w", stdout) do io
            println(io,mailfile(payload))
            # close(io)
        end
    "ok"
end

using Dates

route("/api/send", method="POST") do
    payload = jsonpayload()

    ts = [ "#$tag" for tag in payload["tags"]
                           if !(tag in ["inbox", "new", "flagged","draft","draftversion","attachment"])]
    Notmuch.msmtp(
    mailfile(payload;
             subject = payload["subject"] *
                 ( isempty(ts) ? "" : "   " * join(ts, " ")));
        ## todo: parse from file!
        msmtp_sender = payload["from"],
        mail_dir = expanduser("~/.msmtpqueue"),
        mail_file = Dates.format(now(),"yyyy-mm-dd-HH.MM.SS")
    )
    "ok"
end

route("/notmuch/tree") do
    @show getpayload()
    json(Notmuch.notmuch_tree(
        payload[:q];
        user = get(payload,:user,nothing)))
end

route("/admin/quickpoll") do
    quickpoll!(user = get(payload,:user,nothing))
end

route("/admin/offlineimap") do
    offlineimap!(user = get(payload,:user,nothing))
end

route("/api/" * "delete", method="POST") do
    payload = jsonpayload()
    @info "delete" payload
    for f in p["filename"]
        rm(f)
    end
    notmuch("new"; user = get(payload, "user", nothing))
    close(io)
    "ok"
end

Genie.up()
