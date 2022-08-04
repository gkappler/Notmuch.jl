using Documenter
using Notmuch

DocMeta.setdocmeta!(Notmuch, :DocTestSetup, quote
                        ENV["NOTMUCHJL"] = "/mnt/windows/elmail"
                        ENV["MAILDIR"] = "/home/gregor"
                        ENV["NOHOME"] = "/home/gregor"
                    end; recursive=true)

makedocs(
    sitename = "Notmuch",
    format = Documenter.HTML(),
    modules = [Notmuch]
)

# Documenter can also automatically deploy documentation to gh-pages.
# See "Hosting Documentation" and deploydocs() in the Documenter manual
# for more information.
#=deploydocs(
    repo = "<repository url>"
)=#
