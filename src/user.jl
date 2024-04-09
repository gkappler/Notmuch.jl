
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
function userENV(; workdir= get(ENV,"NOTMUCH_WD",pwd())
                 , homes = joinpath(workdir, "home")
                 , user = get(ENV,"NOTMUCH_USER",nothing), kw...)
    if user === nothing || user == ""
        home = get(ENV,"NOHOME",ENV["HOME"])
        Dict("HOME" => home
             , "MAILDIR" => get(ENV,"NOMAILDIR", get(ENV,"MAILDIR",home)))
    else
        Dict("HOME" => joinpath(homes,user)
             , "MAILDIR" => joinpath(homes,user,"maildir"))
    end
end

export usernames
function usernames(; workdir= get(ENV,"NOTMUCHJL",pwd())
                   , homes = joinpath(workdir, "home"))
    filter(x->isdir(joinpath(homes,x)), readdir(homes))
end

export offlineimap!
