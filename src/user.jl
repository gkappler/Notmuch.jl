
"""
    checkpath!(x)

`!isdir(x) && mkpath(x)`
"""
checkpath!(x) = !isdir(x) && mkpath(x)

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
    if user === nothing || user == ""
        Dict("HOME" => get(ENV,"NOHOME",ENV["HOME"])
             , "MAILDIR" => get(ENV,"NOMAILDIR", ENV["MAILDIR"]))
    else
        Dict("HOME" => joinpath(homes,user)
             , "MAILDIR" => joinpath(homes,user,"maildir"))
    end
end

export offlineimap!

"""
    offlineimap!(; cfg = ".offlineimaprc", kw...)

Run system Cmd `offlineimap` and then [`notmuch_new`](@ref).
Returns output of both.

For user `kw...` see [`userENV`](@ref).
"""
function offlineimap!(; cfg = ".offlineimaprc", kw...)
    env = userENV(; kw...)
    r = try
        read(Cmd(`offlineimap -c $cfg`; dir = env["HOME"], env=env), String)
    catch e
        @error "offlineimap error" e
    end
    rnew = read(notmuch_cmd("new"; kw...),String)
    ##noENV!()
    (offlineimap = r, notmuch_new = rnew)
end
