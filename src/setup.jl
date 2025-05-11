
function maildir(;kw...)
    env = userENV(; kw...)
    chomp(notmuch(:config, "get", "database.path"))
end

function primary_email(;kw...)
    env = userENV(; kw...)
    chomp(notmuch(:config, "get", "user.primary_email"))
end

export notmuch_config
function notmuch_config(; kw... )
    env = userENV(; kw...)
    cfg_file = joinpath(env["HOME"], ".notmuch-config")
    result = tryparse(parse_notmuch_cfg(),read(cfg_file, String); trace=true, log=true)
    if result isa Dict
        result[:folders]= maildirs(result[:database][:path]; kw...)
        result
    end
end

function offlineimap_config(;kw... )
    env = userENV(; kw...)
    cfg_file = joinpath(env["HOME"], ".offlineimaprc")
    prsr = (parse_cfg(
        splitter("accounts";delim=",")))
    parse(prsr,read(cfg_file, String))
end

function notmuch_setup(; kw...)
    env = userENV(; kw...)
    notmuch_setup(env["HOME"], env["MAILDIR"]; kw...)
end

function maildirs(base, outbase="", result=String[]; kw... )
    ismaildir(f) = isdir(joinpath(f,"cur")) && isdir(joinpath(f,"new")) && isdir(joinpath(f,"tmp"))
    env = userENV(; kw...)
    subfolders = [ f for f in readdir(joinpath(env["HOME"], base))
                      if isdir(joinpath(env["HOME"], base,f))
                          ]
    for f in subfolders
        if ismaildir(joinpath(env["HOME"], base,f))
            push!(result, joinpath(outbase,f))
        else
            maildirs(joinpath(base,f), joinpath(outbase,f), result; kw... )
        end
    end
    result
end

export notmuch_setup
function notmuch_setup(home, maildir; name, primary_email, kw...)
    cfg_file = joinpath(home, ".notmuch-config")
    full_maildir = startswith(maildir,"/") ? maildir : joinpath(home, maildir)
    if !isdir(full_maildir)
        @warn "creating maildir $maildir"
        mkdir(full_maildir)
    end
    open(cfg_file,"w") do io
    println(io,"""
# .notmuch-config - Configuration file for the notmuch mail system
#
# For more information about notmuch, see https://notmuchmail.org

# Database configuration
#
# The only value supported here is 'path' which should be the top-level
# directory where your mail currently exists and to where mail will be
# delivered in the future. Files should be individual email messages.
# Notmuch will store its database within a sub-directory of the path
# configured here named ".notmuch".
#
[database]
path=$full_maildir

# User configuration
#
# Here is where you can let notmuch know how you would like to be
# addressed. Valid settings are
#
#	name		Your full name.
#	primary_email	Your primary email address.
#	other_email	A list (separated by ';') of other email addresses
#			at which you receive email.
#
# Notmuch will use the various email addresses configured here when
# formatting replies. It will avoid including your own addresses in the
# recipient list of replies, and will set the From address based on the
# address to which the original email was addressed.
#
[user]
name=$name
primary_email=$primary_email
# Configuration for "notmuch new"
#
# The following options are supported here:
#
#	tags	A list (separated by ';') of the tags that will be
#		added to all messages incorporated by "notmuch new".
#
#	ignore	A list (separated by ';') of file and directory names
#		that will not be searched for messages by "notmuch new".
#
#		NOTE: *Every* file/directory that goes by one of those
#		names will be ignored, independent of its depth/location
#		in the mail store.
#
[new]
tags=new
ignore=/.*[.](json|lock|bak)|[.]git\$/

# Search configuration
#
# The following option is supported here:
#
#	exclude_tags
#		A ;-separated list of tags that will be excluded from
#		search results by default.  Using an excluded tag in a
#		query will override that exclusion.
#
[search]

# Maildir compatibility configuration
#
# The following option is supported here:
#
#	synchronize_flags      Valid values are true and false.
#
#	If true, then the following maildir flags (in message filenames)
#	will be synchronized with the corresponding notmuch tags:
#
#		Flag	Tag
#		----	-------
#		D	draft
#		F	flagged
#		P	passed
#		R	replied
#		S	unread (added when 'S' flag is not present)
#
#	The "notmuch new" command will notice flag changes in filenames
#	and update tags, while the "notmuch tag" and "notmuch restore"
#	commands will notice tag changes and update flags in filenames
#
[maildir]
synchronize_flags=true

        """)
        #notmuch()
    end
end
