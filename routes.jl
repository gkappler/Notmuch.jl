using Genie, Genie.Renderer, Genie.Renderer.Html, Genie.Renderer.Json, SearchLight, Emails
using Genie.Requests
using Genie.Responses

ENV["msmtp_outdir"] = "/home/gregor/.msmtpqueue"

route("/") do
  serve_static_file("welcome.html")
end

using EmailsController
 
route("/email", EmailsController.index)

using ThreadsController

notmuch_commands_json = [
    "search" => "Search for messages matching the given search terms.",
    "address" => "Get addresses from messages matching the given search terms.",
    "show" => "Show all messages matching the search terms.",
    "reply" => "Construct a reply template for a set of messages.",
    "count" => "Count messages matching the search terms.",
]

route("/thread", ThreadsController.index)
route("/show/tree", ThreadsController.tree)
# notmuch search
route("/count", ThreadsController.count)

optionstring(x; kw...) =  [ optionstring(e;kw...) for e in pairs(x) ]
function optionstring(x::Pair;omit=x->false)
    if omit(x.first)
        x.second
    elseif x.second == ""
        "--$(x.first)"
    else
        "--$(x.first)=$(x.second)"
    end
end

"""
    omitq(x)
    omitqtags(x)

`q` is the query parameter for the search argument in notmuch.

Where it applies (`notmuch tag`) `tags` is the tag flag query `+add` and `-remove`.

Other query parameters are passed as is to `notmuch` as `--setting=value`.
"""
omitq(x) = x == :q
omitqtags(x) = (x == :q) || (x==:tags)


route("/json/" * "tagcount") do 
    Genie.Responses.setheaders(Dict(
        "Access-Control-Allow-Origin" =>
            get(Genie.Requests.getheaders(), "Origin","localhost")))
    @show ts = Notmuch.notmuch_json("search", "--output=tags", optionstring(getpayload(), omit = omitq)...)
    basq = getpayload()[:q]
    @show r = [ (tag=t, count=parse(Int,chomp(Notmuch.notmuch("count", @show "($basq) and tag:$t"))))
           for t in ts ]
    json(r)
end

route("/json/" * "address") do 
    Genie.Responses.setheaders(Dict(
        "Access-Control-Allow-Origin" =>
            get(Genie.Requests.getheaders(), "Origin","localhost")))
    json(Notmuch.notmuch_json("address", optionstring(getpayload(), omit = omitq)...))
end

route("/json/" * "search") do 
    Genie.Responses.setheaders(Dict(
        "Access-Control-Allow-Origin" =>
            get(Genie.Requests.getheaders(), "Origin","localhost")))
    json(Notmuch.notmuch_json("search", optionstring(getpayload(), omit = omitq)...))
end

route("/json/" * "show") do 
    Genie.Responses.setheaders(Dict(
        "Access-Control-Allow-Origin" =>
            get(Genie.Requests.getheaders(), "Origin","localhost")))
    json(Notmuch.notmuch_json(
        "show", optionstring(getpayload(),
                             omit = omitq)...))
end


route("/json/" * "count") do 
    Genie.Responses.setheaders(Dict(
        "Access-Control-Allow-Origin" =>
            get(Genie.Requests.getheaders(), "Origin", "localhost")))
    json(parse(Int,chomp(Notmuch.notmuch("count", optionstring(getpayload(), omit = omitq)...))))
end

route("/json/" * "count", method="POST") do
    @show p = jsonpayload()
    basq = get(p,"base-query",nothing)
    ts = p["sub-queries"]
    r = [ parse(Int,chomp(Notmuch.notmuch("count", basq !== nothing ? "($basq) and ($t)" : t)))
           for t in ts ]
    Genie.Responses.setheaders(Dict(
        "Access-Control-Allow-Origin" =>
            get(Genie.Requests.getheaders(), "Origin", "*")))
    json(r)
end


route("/mimepart") do
    pars = Notmuch.notmuch_json("show", "--format=json", optionstring(getpayload(), omit = omitq)...)
    
    Genie.Responses.setheaders(
        "content-type" => pars["content-type"])
    Notmuch.notmuch("show", optionstring(getpayload(), omit = omitq)...)
end




route("/json/" * "reply") do 
    Genie.Responses.setheaders(Dict(
        "Access-Control-Allow-Origin" =>
            get(Genie.Requests.getheaders(), "Origin","localhost")))
    json(Notmuch.notmuch_json("reply", optionstring(getpayload(), omit = omitq)...))
end



using SMTPClient

function print_mailfile(io::IO,payload)
    io = SMTPClient.get_body(
        get(payload,"to",String[]),
        payload["from"],
        payload["subject"],
        payload["body"];
        cc = get(payload,"cc",String[]),
        replyto = get(payload, "replyto", ""),
        messageid=get(payload, "messageid", ""),
        inreplyto= get(payload, "in_reply_to", ""),
        references= get(payload, "references", ""),
        ## attachments file upload mechanism?
        # save in attachments/:mailfilename/uploadfilen.ame
        attachments = get(payload, "attachments", String[])
    )
    s = String(take!(io))
    println(io,s)
end


    
route("/api/" * "save", method="POST") do
    payload = jsonpayload()
    @info "saving" payload
    open(
        Notmuch.notmuch_cmd(
            "insert", "--create-folder" ,"--folder=elmail",
            payload["tags"]...
        ),
        "w", stdout) do io
            print_mailfile(io, payload)
            # close(io)
        end
    "ok"
end

route("/api/send", method="POST") do
    payload = jsonpayload()
    @info "send" payload
    for f in payload["filename"]
        mv(f, joinpath(ENV["msmtp_outdir"], basename(f)))
    end
    Notmuch.notmuch("new")
    close(io)

    run(`/usr/share/doc/msmtp/examples/msmtpqueue/msmtp-runqueue.sh`)
    #run(`/mnt/data/Users/gkapp/Documents/Programme/notmuch-quickpoll.sh`)
    "ok"
end



route("/api/" * "delete", method="POST") do
    payload = jsonpayload()
    @info "delete" payload
    for f in p["filename"]
        rm(f)
    end
    Notmuch.notmuch("new")
    close(io)
    "ok"
end

# route("/api/" * "send", method="POST") do
#     @show p = jsonpayload()
#     isempty(p["filename"])
# end

# Notmuch.notmuch("insert", "--create-folder" ,"--folder=mytest")


route("/api/" * "tag") do 
    @show Notmuch.notmuch("tag", optionstring(getpayload(), omit = omitqtags)...)
    ""
end


Expr(:block, [    quote
        route("/json/"*$c) do
            json(Notmuch.notmuch_json($c, optionstring(params,omit=x->x==:q)...))
        end
     end
     for (c,d) in notmuch_commands_json
]) |> println

# HTML
route("/search", ThreadsController.search, named = :search_threads)

# HTML
#route("/json/search", ThreadsController.search, named = :search_threads)

route("/notmuch/tree") do
    @show getpayload()
    json(Notmuch.notmuch_tree(getpayload()[:q]))
end


#   Find and import new messages to the notmuch database.
route("/api/fetch") do
end
notmuch_commands_admin = [
    "tag" => "Add/remove tags for all messages matching the search terms.",
    
    "help" => "This message, or more detailed help for the named command.",
    "emacs" => "send mail with notmuch and emacs.",
    "new" => "Find and import new messages to the notmuch database.",
    "config" =>"Get or set settings in the notmuch configuration file.",

    "insert" => "Add a new message into the maildir and notmuch database.",

    "dump" => "Create a plain-text dump of the tags for each message.",
    "restore" =>"Restore the tags from the given dump file (see 'dump').",
    "compact" =>"Compact the notmuch database.",
    "reindex" =>"Re-index all messages matching the search terms.",
]

for c in notmuch_commands_admin
    route("/admin/$c") do
        json(Notmuch.notmuch(c, optionstrings(params,omit=x->x==:q)))
    end
end

route("/admin/quickpoll") do
    run(`/mnt/data/Users/gkapp/Documents/Programme/notmuch-quickpoll.sh`)
    "ok"
end

route("/admin/offlineimap") do
    run(`offlineimap`)
    run(`/mnt/data/Users/gkapp/Documents/Programme/notmuch-quickpoll.sh`)
    "ok"
end


notmuch_commands_off = [

    # "setup" => "Interactively set up notmuch for first use.",
]
