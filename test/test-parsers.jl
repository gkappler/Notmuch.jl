@test Notmuch.email_parser(" some wrong@email.de (Name)") == (name = "some Name", email = Mailbox("wrong","email.de"))

julia> Notmuch.move_rule_parser("mv \"from\" \"to\" 10 not tag:inbox",trace=true)
Notmuch.MailsRule{Notmuch.FolderChange}(Notmuch.FolderChange("from", "to"), 10, not:tag:inbox)
