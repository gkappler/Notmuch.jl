using Documenter
using Notmuch

DocMeta.setdocmeta!(Notmuch, :DocTestSetup, quote
                        using Notmuch
                        ENV["NOTMUCHJL"] = "/mnt/windows/elmail"
                        ENV["MAILDIR"] = "/home/gregor"
                        ENV["NOHOME"] = "/home/gregor"
                    end; recursive=true)

makedocs(
    sitename = "Notmuch",
    format = Documenter.HTML(),
    modules = [Notmuch]
)

deploydocs(
    repo = "github.com/gkappler/Notmuch.jl.git",
)
