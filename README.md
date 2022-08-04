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
`joinpath(ENV["NOTMUCHJL"],"home")`.

(Please note, that this package is a prerelease, and such names might still change.)

If you do not have notmuch installed, you can use `docker-compose` to run a dockerized version (inconvenient for a REPL, but convenient for using the HTTP Api).
## Counts

````julia
using Notmuch
notmuch_count("notmuch.jl julia")
````

````
1
````

## Search

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
         mail@g-kappler.de #delete #draft #draftversion #elmail #flagged #important #inbox #notmuch #todo #unread
````

## Trees

````julia
notmuch_tree(Emails,"notmuch.jl julia")
````

````
1-element Vector{Vector{Notmuch.WithReplies{Nothing, Vector{Union{Nothing, Notmuch.WithReplies{Nothing}}}}}}:
 [
├─ 
│  └─ mail@g-kappler.de #draft #elmail #flagged #important #inbox #notmuch #todo #unread
│     Installation of elmail       June 01
│     
│     └─ 
├─ 
└─ 
   └─ 
      ├─ 
      └─ 
         └─ 
            └─ 
               ⋮
               
]
````

Julia types are also provided for `Email`, `Header`, `Mailbox` adresses
and `content`.

The entire tree:

````julia
notmuch_tree(Emails,"notmuch.jl julia", entire_thread=true)
````

````
1-element Vector{Vector{Notmuch.WithReplies{Email, Vector{Any}}}}:
 [mail@g-kappler.de #draft #notmuch #todo #unread
Notmuch Elmail -- Agenda       March 13

├─ mail@g-kappler.de #draft #draftversion #flagged #inbox #notmuch #unread
│  Installation of elmail       March 14
│  
│  └─ mail@g-kappler.de #draft #elmail #flagged #important #inbox #notmuch #todo #unread
│     Installation of elmail       June 01
│     
│     └─ mail@g-kappler.de #draft #inbox #todo #unread
│        Encrypting user passwords       June 01
│        
├─ mail@g-kappler.de #draft #flagged #inbox #notmuch #todo #unread
│  Attachments       March 14
│  
└─ mail@g-kappler.de #draft #draftversion #inbox #unread
   test1       June 01
   
   └─ mail@g-kappler.de #draft #draftversion #inbox #unread
      test1       June 01
      
      ├─ mail@g-kappler.de #delete #draft #inbox #unread
      │  test1       June 01
      │  
      └─ mail@g-kappler.de #draft #draftversion #inbox #unread
         test1       June 01
         
         └─ mail@g-kappler.de #draft #draftversion #inbox #unread
            test1       June 01
            
            └─ mail@g-kappler.de #draft #draftversion #inbox #unread
               test1       June 01
               
               ⋮
               
]
````

## Tagging
you can also tag messages

````julia
notmuch_tag("notmuch.jl julia" => "-important")
notmuch_tag("notmuch.jl julia" => "+important")

notmuch_search(Thread, "notmuch.jl julia")
````

````
1-element Vector{Thread}:
 June 01 Installation of elmail
         mail@g-kappler.de #delete #draft #draftversion #elmail #flagged #important #inbox #notmuch #todo #unread
````

## Inserting

## JSON3
Without a type argument, notmuch commands are by returning `notmuch` output format by default parsed as JSON3.

# Limitations
Again, the package is currently a prerelease, and structure with `WithReplies` might change.

```julia
using Notmuch

@sentafter Date(2022,1,1)
@threads "notmuch.jl julia"
@headers "notmuch.jl julia"
@emails "notmuch.jl julia"
```

## HTTP API
Genie.jl
is used to provide an json API, exposing the original json output of `notmuch` command line tools via HTTP.

User directories can be queried but authentication of users is not yet implemented.

### elmail.elm
The API also exposes an experimental email client at [http://localhost/elmail?tag:unread](http://localhost/elmail?tag:unread):
The code for this functional eλmail messenger has not yet been released!

---

*This page was generated using [Literate.jl](https://github.com/fredrikekre/Literate.jl).*

