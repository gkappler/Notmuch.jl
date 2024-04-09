function new(; kw...)
    rnew = notmuch("new"; kw...)
    ( new = rnew
     , tag = tag_new(; kw...)
     , spam = tag_spam(; kw...)
     )
end

"""
        sync(; kw...)

sync with [`Notmuch.offlineimap.sync`](@ref) and [`Notmuch.gmi.sync`](@ref).
"""
function sync(; kw...)
    (Notmuch.offlineimap.sync(; kw...)
     , Notmuch.gmi.sync(; kw...)
     )
end

module offlineimap
import ..Notmuch: userENV, new

function execute(cmd::Base.Cmd)
    out = IOBuffer()
    err = IOBuffer()
    process = run(pipeline(ignorestatus(cmd), stdout=out, stderr=err))
    return (stdout = String(take!(out)),
            stderr = String(take!(err)),
            code = process.exitcode)
end

"""
    sync(; cfg = ".offlineimaprc", kw...)

Run system Cmd `offlineimap`,  [`notmuch`](@ref)`("new"), [`tag_spam`](@ref), and [`tag_new`](@ref).
Returns Namedtuple output of these.

For user `kw...` see [`userENV`](@ref).
"""
function sync(; cfg = ".offlineimaprc", kw...)
    env = userENV(; kw...)
    r = try
        #read(Cmd(`offlineimap -c $cfg`; dir = env["HOME"], env=env), String)
        execute(Cmd(`offlineimap -c $cfg`; dir = env["HOME"], env=env))
    catch e
        @error "offlineimap error" e
    end
    (offlineimap = r
     , notmuch = new(; kw...))
end

end
@deprecate offlineimap!(;kw...) offlineimap.sync(;kw...)



module gmi
import ..Notmuch: userENV, new 
"""
    sync(; cfg = ".offlineimaprc", kw...)

Run system Cmd `gmi sync`,  [`new`](@ref)`("new")
Returns Namedtuple output of these.

For user `kw...` see [`userENV`](@ref).
"""
function sync(; cfg = ".gmirc", kw...)
    env = userENV(; kw...)
    r = [ begin
             try
                 @info "gmail sync $p with https://github.com/gauteh/lieer"
                 p => read(Cmd(`gmi sync`; dir = joinpath(env["MAILDIR"],p), env=env), String)
             catch e
                 print(e)
             end
             
          end
          for p in readlines(joinpath(env["HOME"], cfg))
              ]
    (gmi = r
     , notmuch = new(; kw...))
end


function send()
    env = userENV(; kw...)
    r = [ begin
             try
                 @info "gmail sync $p with https://github.com/gauteh/lieer"
                 p => read(Cmd(`gmi send -t`; dir = joinpath(env["MAILDIR"],p), env=env), String)
             catch e
                 print(e)
             end
             
          end
          for p in readlines(joinpath(env["HOME"], cfg))
              ]
    (gmi = r
     , notmuch = new(; kw...))
end

end
