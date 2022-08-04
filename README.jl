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
# If you do not have notmuch installed, you can use `docker-compose` to run a dockerized version (inconvenient for a REPL, but convenient for using the HTTP Api).
# ## Counts
using Notmuch
notmuch_count("notmuch.jl julia")

# ## Search

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

# ## Tagging
# you can also tag messages
notmuch_tag("notmuch.jl julia" => "-important")
notmuch_tag("notmuch.jl julia" => "+important")

notmuch_search(Thread, "notmuch.jl julia")

# ## Inserting 

#
# ## JSON3
# Without a type argument, notmuch commands are by returning `notmuch` output format by default parsed as JSON3.

# # Limitations
# Again, the package is currently a prerelease, and structure with `WithReplies` might change.
#
# ```julia
# using Notmuch

# @sentafter Date(2022,1,1)
# @threads "notmuch.jl julia"
# @headers "notmuch.jl julia"
# @emails "notmuch.jl julia"
# ```



# ## HTTP API 
# Genie.jl
# is used to provide an json API, exposing the original json output of `notmuch` command line tools via HTTP.

# User directories can be queried but authentication of users is not yet implemented.

# ### elmail.elm
# The API also exposes an experimental email client at [http://localhost/elmail?tag:unread](http://localhost/elmail?tag:unread):
# The code for this functional eλmail messenger has not yet been released!

