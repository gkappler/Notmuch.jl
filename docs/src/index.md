# Notmuch.jl

## Notmuch wrappers
```@docs
Notmuch
Notmuch.notmuch_cmd
Notmuch.notmuch
Notmuch.notmuch_json
Notmuch.notmuch_count
Notmuch.notmuch_search
Notmuch.notmuch_tree
Notmuch.notmuch_address
Notmuch.notmuch_show
Notmuch.notmuch_insert
```

## Tagging
```@docs
Notmuch.TagChange
Notmuch.notmuch_tag
```

## Multiple user directories
```@docs
Notmuch.userENV
```

## OfflineImap and MSMTP
```@docs
Notmuch.msmtp_runqueue!
Notmuch.msmtp
Notmuch.offlineimap!
Notmuch.checkpath!
```

## Helpers
### Julia email types
```@docs
Notmuch.Emails
Notmuch.Email
Notmuch.Headers
Notmuch.PlainContent
Notmuch.WithReplies
```

### Genie helper functions
```@docs
Notmuch.Key
Notmuch.omitq
Notmuch.optionstring
```
