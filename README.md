```@meta
EditURL = "<unknown>/README.jl"
```

# Notmuch.jl

is a julia wrapper for [notmuch mail](https://notmuchmail.org/) indexer (that supports arbitrary tags and advanced search).
Notmuch mail indexes emails into a xapian database.
Emails need to be stored in maildir standard.
- maildir can be smoothly synchronized with an IMAP server by [offlineimap](http://www.offlineimap.org/).
- maildir is an archiving standard for email datasets. `Notmuch.jl` opens such email data up for analyses in Julia.

On linux with a `notmuch` setup your user mails are searched by default.
Keyword argument `user` switches the `maildir` (and database) to
`joinpath(ENV["NOTMUCH_WD"],"home")`.

(Please note, that this package is a prerelease, and such names might still change.)

## Prerequistes
The package wraps external `Cmd` calls to
1.  notmuch,
2. offlineimap, and
3. msmtp(?)

On most *x OS you can install as packages, e.g.
```
sudo apt install notmuch offlineimap msmtp
```

I would love to merge a pull request adding these libraries as julia artifacts.
### Windows?
I have no idea whether Windows users can use the package installation route. (If you succeed, let us know how!)
But you can use `docker-compose` to run a dockerized version (inconvenient for a REPL, but convenient for using the HTTP Api).

# Email search functions

## Inserting a mail or draft

````julia
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
````

`insert` currently does not return any message id.
One (concurrency unsafe) way to show the inserted message might be:
## Show mail

````julia
notmuch_show(notmuch_search("*", limit=1)[1]["thread"])
````

````
1-element JSON3.Array{JSON3.Array, Base.CodeUnits{UInt8, String}, Vector{UInt64}}:
 JSON3.Array[Any[{
              "id": "notmuch-sha1-18111b839e85f8ec250ec265e045610e347204d2",
           "match": true,
        "excluded": false,
        "filename": [
                      "/home/gregor/.notmuch/drafts/cur/1664281656.M129430P15462.x360:2,S"
                    ],
       "timestamp": 1664281656,
   "date_relative": "0 mins. ago",
            "tags": [
                      "inbox",
                      "new"
                    ],
            "body": [
                      {
                                   "id": 1,
                         "content-type": "text/plain",
                              "content": "Dear Brothers and Sisters,\n\nDo we need decentrally developed open source computer software, that your neighbor can help you (tinker) with?\nPlease sponsor open source tools, that we need in the time to come!\n\nDo you want email search with an unbreakable message archive on your own computer?\nWith no lock in but plain text message files in maildir standard?\nThen you can sponsor my development of Notmuch.jl and eλmail!\n\nPlease sponsor any open source project you would love to manifest!\n\nThank you so much! Love, peace and self mastery to us!\n\nGregor\n\n\n\n"
                      }
                    ],
          "crypto": {},
         "headers": {
                       "Subject": "Please sponsor open source development!   #appeal",
                          "From": "me@crazy.2022",
                            "To": "brothers@crazy.2022, sisters@crazy.2022",
                            "Cc": "holy_cow@confusing.hell, holy_spirit@discerning.heaven",
                           "Bcc": "me@crazy.2022",
                          "Date": "Tue, 27 Sep 2022 14:27:36 +0200"
                    }
}, Union{}[]]]
````

## Mail Counts

````julia
notmuch_count("notmuch.jl julia")
````

````
1
````

## Mail Search

````julia
notmuch_search("notmuch.jl julia")
````

````
1-element JSON3.Array{JSON3.Object, Base.CodeUnits{UInt8, String}, Vector{UInt64}}:
 {
          "thread": "000000000002d396",
       "timestamp": 1654036406,
   "date_relative": "June 01",
         "matched": 1,
           "total": 14,
         "authors": "mail@g-kappler.de",
         "subject": "Installation of elmail",
           "query": [
                      "id:notmuch-sha1-67d8f0dff65266632bfaff7630f04a8c98482e29",
                      "id:notmuch-sha1-756b54b78e9dd073cf0cb37c215ef57ab7735254 id:notmuch-sha1-abefe6c60ca897cffcb81b44adb5235164544a0a id:notmuch-sha1-0bb328d71a9dc822741e27d9ab3b0e3c395981e3 id:notmuch-sha1-292f16ad7cd3d4bfd4f1737e3d0f25100f0f77d4 id:notmuch-sha1-2c0243a912524719f401100e1525414a064321f3 id:notmuch-sha1-4a675f86571e1a78a293754b9125905034d76a08 id:notmuch-sha1-3ee1f8a9e641b0e6eb1fa8588c7456b2d588950e id:notmuch-sha1-ab86307bfaf4587cb41083a2348ba6241e351420 id:notmuch-sha1-1967e388c706adfd8d74cbd250bbb445d7bff53b id:notmuch-sha1-c656afb25d46b9a8dbec1789194082aeb0c15a5a id:notmuch-sha1-df995e509c40b4030dcb658014b5d802e04a2fe4 id:notmuch-sha1-5895c8e46bc5686d51e4949459638132ee1d0533 id:notmuch-sha1-de6c84d7ffd2923d610669d0103ba6182108c188"
                    ],
            "tags": [
                      "delete",
                      "doc",
                      "draft",
                      "draftversion",
                      "elmail",
                      "flagged",
                      "important",
                      "inbox",
                      "notmuch",
                      "todo",
                      "unread"
                    ]
}
````

By default, notmuch json output format is returned.
With the first argument, results are converted to the `Thread` type of `Notmuch.jl`:

````julia
notmuch_search(Thread, "notmuch.jl julia")
````

````
1-element Vector{Thread}:
 June 01 Installation of elmail
         mail@g-kappler.de #delete #doc #draft #draftversion #elmail #flagged #important #inbox #notmuch #todo #unread
````

## Trees

````julia
notmuch_tree(Emails,"notmuch.jl julia")
````

````

└─ 
   └─ 
      ├─ 
      │  └─ June 01 mail@g-kappler.de #doc #draft #elmail #flagged #important #inbox #notmuch #todo #unread
      │     Installation of elmail
      │     └─ 
      ├─ 
      └─ 
         └─ 
            ├─ 
            └─ 
               ⋮
               

````

Julia types are also provided for `Email`, `Header`, `Mailbox` adresses
and `content`.

The entire tree:

````julia
notmuch_tree(Emails,"notmuch.jl julia", entire_thread=true)
````

````

└─ 
   └─ 2022-03-13 mail@g-kappler.de #draft #notmuch #todo #unread
      Notmuch Elmail -- Agenda
      ├─ 2022-03-14 mail@g-kappler.de #draft #draftversion #flagged #inbox #notmuch #unread
      │  Installation of elmail
      │  └─ June 01 mail@g-kappler.de #doc #draft #elmail #flagged #important #inbox #notmuch #todo #unread
      │     Installation of elmail
      │     └─ June 01 mail@g-kappler.de #draft #inbox #todo #unread
      │        Encrypting user passwords
      ├─ 2022-03-14 mail@g-kappler.de #draft #flagged #inbox #notmuch #todo #unread
      │  Attachments
      └─ June 01 mail@g-kappler.de #draft #draftversion #inbox #unread
         test1
         └─ June 01 mail@g-kappler.de #draft #draftversion #inbox #unread
            test1
            ├─ June 01 mail@g-kappler.de #delete #draft #inbox #unread
            │  test1
            └─ June 01 mail@g-kappler.de #draft #draftversion #inbox #unread
               test1
               ⋮
               

````

## Tagging of mails (matching a search)
you can also tag messages

````julia
notmuch_tag("notmuch.jl julia" => "-important")
notmuch_tag("notmuch.jl julia" => "+important")

notmuch_search(Thread, "notmuch.jl julia")
````

````
1-element Vector{Thread}:
 June 01 Installation of elmail
         mail@g-kappler.de #delete #doc #draft #draftversion #elmail #flagged #important #inbox #notmuch #todo #unread
````

## JSON3
Without a type argument, notmuch commands are by returning `notmuch` output format by default parsed as JSON3.

## HTTP API
Genie.jl
is used to provide an json API, exposing the original json output of `notmuch` command line tools via HTTP.

User directories can be queried but authentication of users is not yet implemented.

### elmail.elm
The API also exposes an experimental email client at [http://localhost/elmail?tag:unread](http://localhost/elmail?tag:unread):
The code for this functional eλmail messenger has not yet been released!

# Limitations
Again, the package is currently a prerelease, and structure with `WithReplies` might change.

# Macros would be nice:
```julia
using Notmuch

@sentafter Date(2022,1,1)
@threads "notmuch.jl julia"
@headers "notmuch.jl julia"
@emails "notmuch.jl julia"
```

---

*This page was generated using [Literate.jl](https://github.com/fredrikekre/Literate.jl).*

