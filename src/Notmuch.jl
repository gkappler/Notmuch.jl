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

export offlineimap!
checkdir(x) = !isdir(x) && mkdir(x)
function userENV!(; workdir= get(ENV,"NOTMUCHJL",pwd())
                  , homes = joinpath(workdir, "home")
                  , user = nothing)
    ## @show user
    if user === nothing 
        paths = (workdir = workdir
                 , home = ENV["NOHOME"] # ENV["NOTMUCHJL_HOME"]
                 , maildir = ENV["NOMAILDIR"])
    else
        paths = (workdir = workdir
                 , home = joinpath(homes,user)
                 , maildir = joinpath(homes,user,"mail"))
    end
    ENV["HOME"] = paths.home
    ENV["MAILDIR"] = paths.maildir
    paths
end

function noENV!(; workdir= get(ENV,"NOTMUCHJL",pwd()))
    paths = (workdir = workdir
             , home = ENV["NOHOME"] # ENV["NOTMUCHJL_HOME"]
             , maildir = ENV["NOMAILDIR"])
    ENV["HOME"] = paths.home
    ENV["MAILDIR"] = paths.maildir
    cd(paths.workdir)
    paths
end

"""
    notmuch(x...;
                 workdir= get(ENV,"NOTMUCH_ROOT",pwd())
                 , homes = joinpath(workdir, "home")
                 , user = nothing, kw...)

Run `notmuch_cmd`, after `cd(home)` and returning `cd(workdir)`.
(see [`userENV!`](@ref)).
"""
function notmuch(x...; kw...)
    paths = userENV!(; kw...)
    cd(paths.home)
    r = try
        read(notmuch_cmd("--config=.notmuch-config",x...), String)
    catch e
        @error "notmuch error" e
    end
    noENV!()
    r
end


function offlineimap!(; kw...)
    @show paths = userENV!(; kw...)
    cd(paths.home)
    r = try
        read(`offlineimap -c .offlineimaprc`, String)
    catch e
        @error "offlineimap error" e
    end
    rnew = read(notmuch_cmd("new"),String)
    noENV!()
    (r, rnew)
end



"""
    notmuch_cmd(command, x...; user=nothing)


!!! note
    running the command as a different user (`user !== nothing`) 
    is untested:
    `sudo -u \$user -i ...`
"""
function notmuch_cmd(command, x...; user=nothing)
    y = [x...]
    if user===nothing
        `/usr/bin/notmuch $command $y`
    else
        `sudo -u $user -i /usr/bin/notmuch $command $y`
    end
end

##export notmuch
##notmuch(command,x...; kw...) = read(notmuch(command, x...; kw...), String)

notmuch_json(command,x...; kw...) = 
    JSON3.read(notmuch(command, "--format=json", x...; kw...))

function notmuch_count(x...; kw...)
    c = notmuch("count", x...; kw...)
    parse(Int,chomp(c))
end

export notmuch_search
include("Threads.jl")

notmuch_search(T::Type, x...; kw...) = T.(notmuch_search(x...; kw...))
notmuch_search(x...; offset=0, limit=5, kw...) =
    notmuch_json(:search, "--offset=$offset", "--limit=$limit", x...; kw...)

notmuch_show(T::Type, x...; kw...) = T.(notmuch_show(x...; kw...))
notmuch_show(x...; kw...) = notmuch_json(:show, x...; kw...)

export notmuch_tree

"""
    notmuch_tree(x...)

Parsimonous tree query for fetching structure with
`notmuch_show("--body=false", "--entire-thread", x...; kw...)`
"""
function notmuch_tree(x...; kw...)
    notmuch_show("--body=false", "--entire-thread", x...; kw...)
end



export TagChange, notmuch_tag
struct TagChange
    prefix::String
    tag::String
end

function notmuch_tag(batch::Vector{Pair{String,TagChange}}; kw...)
    open(
        Notmuch.notmuch_cmd(
            "tag", "--batch"; kw...
        ),
        "w", stdout) do io
            for (q, tc) in batch
                @info "tag $q" tc
                # println(tc.prefix,
                #         replace(tc.tag, " " => "%20")
                #         , " -- ", q)
                println(io, tc.prefix,
                        replace(tc.tag, " " => "%20")
                        , " -- ", q)
            end
            # close(io)
        end
end

export notmuch_insert
function notmuch_insert(mail; folder="juliatest")
    so,si,pr = notmuch_readandwrite("insert", "--folder=$folder")
    write(si, mail)
    close(si)
    readall(so)
end



using Dates


end
