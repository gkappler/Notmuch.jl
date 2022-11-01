@show @__DIR__
@show pwd()
(pwd() != @__DIR__) && cd(@__DIR__) # allow starting app from bin/ dir
using Pkg
Pkg.activate(".")

using SMTPClient
using Notmuch
# push!(Base.modules_warned_for, Base.PkgId(Notmuch))
Notmuch.main()
