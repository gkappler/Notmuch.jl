# using Pkg
using Genie, Genie.Renderer, Genie.Renderer.Html, Genie.Renderer.Json
using Genie.Requests
using Genie.Responses

using Notmuch
ENV["NOTMUCHJL"] = "/mnt/windows/elmail"
ENV["MAILDIR"] = "/home/gregor"
ENV["NOHOME"] = "/home/gregor"

include("config/env/dev.jl")

## ENV["msmtp_outdir"] = "/home/gregor/.msmtpqueue"

# route("/json/" * "users") do 
#     json(readdir(joinpath(ENV["NOTMUCHJL"],"home")))
# end

route("/json/" * "from") do 
    payload = getpayload()
    json([ c.from for c in msmtp_config(; payload...) ])
end

route("/json/" * "count") do 
    payload = getpayload()
    json(parse(Int,chomp(Notmuch.notmuch(
        "count", optionstring(payload, omit = omitq)...,
        payload["q"];
        user = get(payload,:user,nothing)))))
end
# route("/json/" * "count", "POST") do 
#     payload = jsonpayload()
#     json(parse(Int,chomp(Notmuch.notmuch(
#         "count", optionstring(payload, omit = omitq)...;
#         user = get(payload,"user",nothing)))))
# end

route("/json/" * "count", method="POST") do
    p = jsonpayload()
    @info "count" p
    basq = get(p,"base_query",nothing)
    ts = p["sub_queries"]
    r = if isempty(ts)
        [ notmuch_count(optionstring(p, omit = x -> x in [:user, :base_query, :sub_queries])...,
                      basq;
                        user = get(p,"user",nothing))
          ]
    else
        r = [ parse(Int,chomp(Notmuch.notmuch(
            "count", basq !== nothing ? "($basq) and ($t)" : t;
            user = get(p,"user",nothing))))
              for t in ts ]
    end
    json(r)
end

route("/json/" * "tagcount") do 
    # Genie.Responses.setheaders(Dict(
    #     "Access-Control-Allow-Origin" =>
    #         get(Genie.Requests.getheaders(), "Origin","localhost")))
    payload = getpayload()
    basq = payload[:q]
    ts = Notmuch.notmuch_json(
        "search", "--output=tags",
        optionstring(payload, omit = omitq)...,
        payload["q"];
        user = get(payload,:user,nothing))
    r = [ (tag=t, count=parse(Int,chomp(
        Notmuch.notmuch(
            "count", "($basq) and tag:$t";
            user = get(payload,:user,nothing)))))
    for t in ts ]
    json(r)
end

route("/json/" * "tagcount", method="POST") do 
    payload = jsonpayload()
    basq = payload["q"]
    ts = Notmuch.notmuch_json(
        "search", "--output=tags",
        optionstring(payload, omit = omitq)...,
        payload["q"];
        user = get(payload,"user",nothing))
    r = [ (tag=t, count=parse(Int,chomp(
        Notmuch.notmuch(
            "count", "($basq) and tag:$t";
            user = get(payload,"user",nothing)))))
    for t in ts ]
    json(r)
end

route("/json/" * "address") do 
    payload = getpayload()
    json(Notmuch.notmuch_json(
        "address", optionstring(payload, omit = omitq)...,
        "--output==count",
        payload["q"];
        user = get(payload,:user,nothing)))
end

route("/json/" * "address",method="POST") do 
    payload = jsonpayload()
    json(Notmuch.notmuch_address(
        payload["q"],
        "--output=count",
        optionstring(payload, omit = omitq)...;
        target = get(payload,"target",nothing),
        user = get(payload,"user",nothing)))
end

route("/json/" * "search") do 
    payload = getpayload()
    json(Notmuch.notmuch_json(
        "search", optionstring(payload, omit = omitq)...,
        payload["q"];
        user = get(payload,:user,nothing)))
end

route("/json/" * "search",method="POST") do 
    payload = jsonpayload()
    json(Notmuch.notmuch_json(
        "search", optionstring(payload, omit = omitq)...,
            payload["q"]
            ;
        user = get(payload,"user",nothing)))
end

route("/notmuch/tree") do
    @show getpayload()
    json(Notmuch.notmuch_tree(
        payload[:q];
        user = get(payload,:user,nothing)))
end

route("/json/" * "show") do 
    payload = getpayload()
    json(Notmuch.notmuch_json(
        "show", optionstring(payload,
                             omit = omitq)...,
        payload["q"];
        user = get(payload,:user,nothing)))
end

route("/json/" * "show", method="POST") do 
    payload = jsonpayload()
    json(Notmuch.notmuch_json(
        "show", optionstring(payload,
                             omit = omitq)...,
        payload["q"];
        user = get(payload,"user",nothing)))
end


route("/mimepart") do
    payload = getpayload()
    pars = Notmuch.notmuch_json(
        "show", optionstring(payload, omit = omitq)...,
        payload[:q];
        user = get(payload,:user,nothing))
    
    Genie.Responses.setheaders(
        "content-type" => pars["content-type"])
    Notmuch.notmuch(
        "show", optionstring(payload, omit = omitq)...,
        payload[:q];
        user = get(payload,:user,nothing))
end

route("/mimepart",method="POST") do
    payload = jsonpayload()
    pars = Notmuch.notmuch_json(
        "show", optionstring(payload, omit = omitq)...,
        payload["q"];
        user = get(payload,"user",nothing))
    
    Genie.Responses.setheaders(
        "content-type" => pars["content-type"])
    Notmuch.notmuch(
        "show", optionstring(payload, omit = omitq)...,
        payload["q"];
        user = get(payload,:user,nothing))
end




route("/api/" * "tag", method="POST") do
    payload = jsonpayload()
    @info "tagging" payload["q"] payload["tags"]
    notmuch_tag(
        [ payload["q"] => TagChange(tc["action"], tc["tag"])
          for tc in payload["tags"]];
        user = get(payload, "user", nothing))
    "ok"
end



route("/json/" * "reply") do 
    # Genie.Responses.setheaders(Dict(
    #     "Access-Control-Allow-Origin" =>
    #         get(Genie.Requests.getheaders(), "Origin","localhost")))
    payload = getpayload()
    json(Notmuch.notmuch_json(
        "reply", optionstring(payload, omit = omitq)...,
        payload[:q]
        ;
        user = get(payload,:user,nothing)))
end


route("/json/" * "reply", method="POST") do 
    # Genie.Responses.setheaders(Dict(
    #     "Access-Control-Allow-Origin" =>
    #         get(Genie.Requests.getheaders(), "Origin","localhost")))
    payload = jsonpayload()
    json(Notmuch.notmuch_json(
        "reply", optionstring(payload, omit = omitq)...,
        payload["q"]
            ;
        user = get(payload,"user",nothing)))
end


using Dates

route("/api/send", method="POST") do
    payload = jsonpayload()
    rfc = rfc_mail(;(Symbol(k) => v for (k,v) in payload)...)
    @info "sending" payload["from"] payload["subject"]
    println(rfc)
    Notmuch.msmtp(
        rfc;
        ## todo: parse from file!
        msmtp_sender = Notmuch.author_email(payload["from"]).email,
        mailfile = Dates.format(now(),"yyyy-mm-dd-HH.MM.SS")
        , user=payload["user"]
    )
    Notmuch.msmtp_runqueue!(;user=payload["user"])
end
    
route("/api/" * "save", method="POST") do
    ## attachments file upload mechanism?
    # save in attachments/:rfc_mailname/uploadfilen.ame
    payload = jsonpayload()
    rfc = rfc_mail(
        ;(Symbol(k) => v for (k,v) in payload
              if k != "tags")...);
    @info "saving" payload["from"] payload["subject"]
    println(rfc)
    notmuch_insert(rfc
                   ; tags = payload["tags"]
                   , folder="elmail"
                   , user=payload["user"]
                   )
    "ok"
end

route("/admin/quickpoll", method="POST") do
    payload = jsonpayload()
    r = offlineimap!(user = get(payload,"user",nothing))
    json(r)
end

route("/admin/offlineimap", method="POST") do
    payload = jsonpayload()
    offlineimap!(user = get(payload,"user",nothing))
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

# Genie.up()

# function pass_insert(pass, path)
#     spath = join(path,"/")
#     open(
#         (`pass insert $spath`),
#         "w", stdout) do io
#             println(io,pass)
#             println(io,pass)
#         end
# end

# route("/api/" * "send", method="POST") do
#     @show p = jsonpayload()
#     isempty(p["filename"])
# end

# Notmuch.notmuch("insert", "--create-folder" ,"--folder=mytest")

#t = "draftversion -new"
#notmuch_search("tag:\"$t\"")
#notmuch_tag(["tag:\"$t\"" => TagChange("-",t)])

# Expr(:block, [    quote
#         route("/json/"*$c) do
#             json(Notmuch.notmuch_json($c, optionstring(params,omit=x->x==:q)...))
#         end
#      end
#      for (c,d) in notmuch_commands_json
# ]) |> println

# HTML
#route("/search", ThreadsController.search, named = :search_threads)

# HTML
#route("/json/search", ThreadsController.search, named = :search_threads)


# using EmailsController
 
# route("/email", EmailsController.index)

# using ThreadsController

#route("/thread", ThreadsController.index)
#route("/show/tree", ThreadsController.tree)
# notmuch search
#route("/count", ThreadsController.count)

notmuch_commands_json = [
    "search" => "Search for messages matching the given search terms.",
    "address" => "Get addresses from messages matching the given search terms.",
    "show" => "Show all messages matching the search terms.",
    "reply" => "Construct a reply template for a set of messages.",
    "count" => "Count messages matching the search terms.",
]

route("/") do
    String(read(open("public/elmail.html","r")))
end

route("main.js") do
    String(read(open("public/main.js","r")))
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
        json(Notmuch.notmuch(
            c, optionstrings(params,omit=x->x==:q);
            user = get(payload,:user,nothing)))
    end
end


notmuch_commands_off = [

    # "setup" => "Interactively set up notmuch for first use.",
]
