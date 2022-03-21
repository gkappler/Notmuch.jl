(pwd() != @__DIR__) && cd(@__DIR__) # allow starting app from bin/ dir

using Notmuch
push!(Base.modules_warned_for, Base.PkgId(Notmuch))
Notmuch.main()
using SMTPClient
