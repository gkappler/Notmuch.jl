module Notmuch
using JSON3

using Genie, Logging, LoggingExtras

function main()
  Core.eval(Main, :(const UserApp = $(@__MODULE__)))

  Genie.genie(; context = @__MODULE__)

  Core.eval(Main, :(const Genie = UserApp.Genie))
  Core.eval(Main, :(using Genie))
end

export notmuch_json, notmuch_search, notmuch_show, notmuch_tree, notmuch_count, notmuch_cmd


function notmuch(x...)
    read(notmuch_cmd(x...), String)
end


function notmuch_cmd(command, x...)
    y = [x...]
    @show c = `/usr/bin/notmuch $command $y`
end

notmuch_json(command,x...) = 
    JSON3.read(notmuch(command, "--format=json", x...))

notmuch_search(x...; limit=50) =
    notmuch_json(:search, "--limit=$limit",x...)

function notmuch_tree(x...)
    #search = "(" * join(x,") and (") * ")"
    # notmuch_json(:show, "--body=false", "--entire-thread", x...)
    notmuch_show("--body=false", "--entire-thread", x...)
end


function notmuch_show(x...)
    #search = "(" * join(x,") and (") * ")"
    notmuch_json(:show, x...)
end

function notmuch_count(x...)
    y = [x...]
    @show c = `/usr/bin/notmuch count $y`
    parse(Int,chomp(read(c, String)))
end

export notmuch_insert
function notmuch_insert(mail; folder="juliatest")
    so,si,pr = notmuch_readandwrite("insert", "--folder=$folder")
    write(si, mail)
    close(si)
    readall(so)
end


function msmtp(
    rfc;
    ## todo: parse from file!
    msmtp_sender = env_msmtp_sender(),
    mail_dir = expanduser("~/.msmtpqueue"),
    mail_file = Dates.format(now(),"yyyy-mm-dd-HH.MM.SS")
    )
    open(joinpath(mail_dir, "$mail_file.msmtp"), "w") do io
        println(io, "-oi -f $msmtp_sender -t")
    end
    dt, tz = Dates.format(now(), DateFormat("e, d u Y HH:MM:SS")), get(ENV, "TIMEZONE", "+0100")
    docs_ascii = print_order(MIME("text/ascii"), mail_orders)
    docs_html = print_order(MIME("text/html"), mail_orders)
    message_id = "" # "Message-ID: <>"
    open(joinpath(mail_dir, "$mail_file.mail"), "w") do io
        println(io, rfc)
    end
end
end
