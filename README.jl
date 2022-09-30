# # Notmuch.jl

# is a julia wrapper for [notmuch mail](https://notmuchmail.org/) indexer (that supports arbitrary tags and advanced search).
# Notmuch mail indexes emails into a xapian database.
# Emails need to be stored in maildir standard.
# - maildir can be smoothly synchronized with an IMAP server by [offlineimap](http://www.offlineimap.org/).
# - maildir is an archiving standard for email datasets. `Notmuch.jl` opens such email data up for analyses in Julia.
# 
# On linux with a `notmuch` setup your user mails are searched by default.
# Keyword argument `user` switches the `maildir` (and database) to
# `joinpath(ENV["NOTMUCHJL"],"home")`.
#
# (Please note, that this package is a prerelease, and such names might still change.)
#
# ## Prerequistes
# The package wraps external `Cmd` calls to
# 1.  notmuch,
# 2. offlineimap, and
# 3. msmtp(?)
# 
# On most *x OS you can install as packages, e.g.
# ```
# sudo apt install notmuch offlineimap msmtp
# ```
#
# Install my SMTPClient fork:
# ```julia
# ] add https://github.com/gkappler/SMTPClient.jl
# ```
#
# I would love to merge a pull request adding these libraries as julia artifacts.
# ### Windows?
# I have no idea whether Windows users can use the package installation route. (If you succeed, let us know how!)
# But you can use `docker-compose` to run a dockerized version (inconvenient for a REPL, but convenient for using the HTTP Api).
#

# # Email search functions

# ## Inserting a mail or draft
using Notmuch
notmuch_insert(
    rfc_mail(from="me@crazy.2022",
             to=[ "brothers@crazy.2022", "sisters@crazy.2022" ],
             cc=[ "holy_cow@confusing.hell",
                  "holy_spirit@discerning.heaven" ],
             bcc=[ "me@crazy.2022" ],
             subject="Please sponsor open source development!",
             tags=[ "draft", "appeal" ],
             body="""
                  Dear Brothers and Sisters, 

                  Do we need decentrally developed open source computer software, that your neighbor can help you (tinker) with?
                  Please sponsor open source tools, that we need in the time to come!

                  Do you want email search with an unbreakable message archive on your own computer?
                  With no lock in but plain text message files in maildir standard?
                  Then you can sponsor my development of Notmuch.jl and eλmail!
                    
                  Please sponsor any open source project you would love to manifest!
        
                  Thank you so much! Love, peace and self mastery to us!

                  Gregor
                  """),
    folder="drafts")

# `insert` currently does not return any message id.
# One (concurrency unsafe) way to show the inserted message might be:
# ## Show mail
notmuch_show(notmuch_search("*", limit=1)[1]["thread"])


# ## Mail Counts
notmuch_count("notmuch.jl julia")

# ## Mail Search

notmuch_search("notmuch.jl julia")

# By default, notmuch json output format is returned.
# With the first argument, results are converted to the `Thread` type of `Notmuch.jl`:

notmuch_search(Thread, "notmuch.jl julia")

#
# ## Trees

notmuch_tree(Emails,"notmuch.jl julia")
# Julia types are also provided for `Email`, `Header`, `Mailbox` adresses 
# and `content`.

# The entire tree:
notmuch_tree(Emails,"notmuch.jl julia", entire_thread=true)

# ## Tagging of mails (matching a search)
# you can also tag messages
notmuch_tag("notmuch.jl julia" => "-important")
notmuch_tag("notmuch.jl julia" => "+important")

notmuch_search(Thread, "notmuch.jl julia")

#
# ## JSON3
# Without a type argument, notmuch commands are by returning `notmuch` output format by default parsed as JSON3.

# ## HTTP API 
# Genie.jl
# is used to provide an json API, exposing the original json output of `notmuch` command line tools via HTTP.

# User directories can be queried but authentication of users is not yet implemented.

# ### elmail.elm
# The API also exposes an experimental email client at [http://localhost/elmail?tag:unread](http://localhost/elmail?tag:unread):
# The code for this functional eλmail messenger has not yet been released!


# # Limitations
# Again, the package is currently a prerelease, and structure with `WithReplies` might change.
#
# # Macros would be nice:
# ```julia
# using Notmuch

# @sentafter Date(2022,1,1)
# @threads "notmuch.jl julia"
# @headers "notmuch.jl julia"
# @emails "notmuch.jl julia"
# ```


