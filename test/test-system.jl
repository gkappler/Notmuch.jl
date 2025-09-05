using Notmuch

using JSON3
using Test
false && include("../src/Notmuch.jl")

home = tempname()
ENV["NOTMUCH_WD"] = home
ENV["NOMAILDIR"] = "mail"
ENV["NOHOME"] = home

mkdir(home)
mkdir(joinpath(home,"mail"))
notmuch_setup(name="Gregor", primary_email="me@organized.mail")

@testset "TagChange" begin
    @test tag"+inbox" == [ TagChange("+","inbox") ]
    @test tag"+inbox +flagged" == [ TagChange("+","inbox"), TagChange("+","flagged") ]
    @test tag"+inbox +flagged -new" == [ TagChange("+","inbox"), TagChange("+","flagged"), TagChange("-","new") ]
end

notmuch_new()
@testset "setup" begin
    @test notmuch_count() == 0
end

@testset "insert and retrieve a draft" begin
    notmuch_insert(rfc_mail("julia REPL","use https://github.com/MasonProtter/ReplMaker.jl"))
    @test notmuch_count() == 1
    #
    let e = Email.(notmuch_ids("subject:'julia REPL'"))[1]
        @test e.headers.Subject == "julia REPL"
        @test e.headers.From == "me@organized.mail"
        @test startswith(e.filename[1], joinpath(home,"mail","Draft"))
        @test ["new"] == e.tags
    end
end


using Dates
@testset "retrieve and reply to feature request" begin
    notmuch_insert(
        rfc_mail(
            "Feature request: REPL integration",    "I like Notmuch.jl. it rould be great to have Julia REPL integration to search and tag emails.";
            from="prospect@good.ideas",  to=["me@organized.mail"],
            date=now()-Day(4),
            message_id = "request"),
        folder="INBOX",
        tag=tag"+inbox +unread")
    #
    let e = Email("request")
        @test e.headers.Subject == "Feature request: REPL integration"
        @test startswith(e.filename[1], joinpath(home,"mail","INBOX"))
        @test ["inbox","new","unread"] == e.tags
    end
    #
    # simulate UI reading mail
    #
    notmuch_tag("id:request" => "-unread")
    #   
    # simulate UI replying to the mail
    #
    notmuch_insert(
        rfc_mail(
            "Re: Feature request: REPL integration", "Great idea!  When I get to it - I will let you know. Any attempts at implementing yourself?";
            from="me@organized.mail", to=["prospect@good.ideas"],
            in_reply_to = "request",
            date=now()-Day(3),
            message_id = "request-acknowledgement"),
        folder="Sent",
        tag=tag"+sent")
    let e = Email("request-acknowledgement")
        @test e.headers.Subject == "Re: Feature request: REPL integration"
        @test startswith(e.filename[1], joinpath(home,"mail","Sent"))
        @test ["new","sent"] == e.tags
    end
    notmuch_tag("id:request" => "+replied")
end

# messages that are not to be moved
#
sticky = "(tag:unread or tag:flagged or date:2days..)"
@testset "actions" begin
    @test Notmuch.query_parser(sticky) |> string == sticky
    @test MailsRule("+draft tag folder:Draft") ==
        [ MailsRule(TagChange("+draft"), "folder:Draft") ]
    @test MailsRule("mv INBOX Archive not tag:inbox") ==
        MailsRule(FolderChange("INBOX", "Archive"), "not tag:inbox")
end

#
# Rules
#
# are based on queries,
# can tag or move
# messages
# and are loged as rfc-compliant mail
# with a summary and
# attachements that will
# reverese the file operations (mv to previous folder)
# or restores the previous tags
# on affected messages

rule"+draft tag folder:Draft" |> apply_rule


rule"-inbox tag tag:spam" |> apply_rule
rule"-inbox tag tag:socialmedia and date:..7d" |> apply_rule

rule"-inbox -new tag from:notmuch.jl" |> apply_rule


MailsRule("mv INBOX Archive not ($sticky) and not tag:inbox") |> apply_rule


@testset "sync inbox tag and INBOX folder" begin
    @test in("inbox",Email("request").tags) && in("replied",Email("request").tags)
    MailsRule("-inbox tag not ($sticky) and tag:replied") |> apply_rule
    @test !in("inbox",Email("request").tags)

    @test startswith(Email("request").filename[1], joinpath(home,"mail","INBOX"))
    MailsRule("mv INBOX Archive not ($sticky) and not tag:inbox") |> apply_rule
    @test startswith(Email("request").filename[1], joinpath(home,"mail","Archive"))

    ## UI: add inbox to move back into inbox 
    notmuch_tag("id:request" => "+inbox", log=true)
    MailsRule("mv Archive INBOX tag:inbox") |> apply_rule
    @test startswith(Email("request").filename[1], joinpath(home,"mail","INBOX"))

    # remove inbox flag and stick it there -- (is this a reasonable rule?)
    notmuch_tag("id:request" => "-inbox +flagged", log=true)
    Notmuch.apply_rules()
    @test startswith(Email("request").filename[1], joinpath(home,"mail","INBOX"))
    
    notmuch_tag("id:request" => "-flagged", log=true)
    apply_rules(log=true)
    @test startswith(Email("request").filename[1], joinpath(home,"mail","Archive"))
end



Notmuch.llm_draft("outreach"; log=true)



@testset "add interested contacts to a tag, e.g. a task" begin
    notmuch_insert(rfc_mail(
        "Plan: julia REPL integration of mails into Notmuch.jl.";
        to = ["prospect@good.ideas"],
        in_reply_to = "request-acknowledgement",
        date = now()-Day(3),
        message_id = "aigent-plan"))
    notmuch_insert(rfc_mail(
        "notmuch tag thread +project/REPL";
        to = ["prospect@good.ideas"],
        in_reply_to = "request-acknowledgement",
        date = now()-Day(3),
        message_id = "aigent-tag"))

    notmuch_insert(
        rfc_mail(
            "Decentralized Messages: good old wine in new LLMs",
            """New forms of messaging are legion today.
        Aging users become demotivated to learn a new one.
        How can we consolidate our knowledge?
        How can we manage the exodus from big tech?

        1. decentralized email archives (Notmuch.jl)
        2. social-media-like user interface (ElMail)
        3. rule-based workflows
        4. premium: customizable artificial intelligence features
        """;
            from="mail@g-kappler.de", to=["Steve Corbett"],
            date=now()-Day(3),
            message_id = "outreach"))

    MailsRule(Notmuch.query("folder:Draft and tag:new and not tag:aigent/done")) do emails
        for id in emails
            Notmuch.llm_drafts(id)
            notmuch_tag("id:$id" => tag"aigent/done")
        end
    end |> apply_rule
end

notmuch_tree(Emails,"folder:.maildir-gmx/Drafts and not tag:aigent/done")

notmuch_insert(
    rfc_mail(
        "test full folder",
        "with body";
        from="mail@g-kappler.de", to=["prospect@good.ideas"]),
    message_id=ids[4] * "test",
    folder=Notmuch.maildir_names(Email(ids[4]).filename[1]).dir)


let q="folder:.maildir-mail-gkappler/Drafts and not tag:aigent/done"
    notmuch_tree(Emails,q)
    ids=notmuch_ids(q)
    println(Email(ids[4]; body=true))
    Notmuch.llm_drafts(ids[4]; log=true)
    
    notmuch_tree("id:"*ids[4])


Notmuch.bla("request")
@testset "AI drafts" begin
    MailsRule("subject:aigent folder:Draft and not tag:aigent/Draft") |> apply_rule
end

apply_rules("from:notmuch.jl")
@testset "AI drafts" begin
    ## UI reply and set subject to add sender to an address book
    notmuch_insert(
        rfc_mail(
            "notmuch tag sender +prospect";
            from="me@organized.mail", to=["prospect@good.ideas"],
            in_reply_to = "request",
            date=now()-Day(3),
            message_id = "10002"))
    
    MailsRule("agent notmuch subject:notmuch folder:Draft") |> apply_rule
    MailsRule("agent ai subject:aigent folder:Draft") |> apply_rule
end

    

# --- Tagging Strategy ---
# Core States: inbox, unread, todo, waiting, later, archive
# Context: client/NAME, project/NAME, finance, invoice, proposal, lead, personal
# Mail Type: newsletter, notification, sent, draft

# --- Key Concepts ---
# * Tag-centric: Classification and state use tags heavily.
# * Empty imbox first!  This must be a goal that can be easily achieved every day -- without narrowing the search lens.
# * Minimal Folders: Often just INBOX, Sent, Drafts, Archive, Spam synced by offlineimap.
# * Queries Drive Views: Use `notmuch_search` or `notmuch show` with queries like
#   "tag:todo", "tag:waiting", "tag:client/Acme and tag:unread" to see relevant mail.
# * Hooks for Automation: Real automation relies on `notmuch` hooks (pre-new, post-new)
#   to apply rules automatically as new mail arrives or changes. The rules above
#   define the *logic* that hooks would trigger.

## For a clean IMAP inbox experience newsletters and similar stuff should be moved.
## OfflineIMAP handles such moves with maildir gracefully.
## Best practice recommendation for email archiving when building on what notmuch is capable of:
## - client-specific archive and inbox folders
## - spam and news folders
## - ...

# --- Folder Strategy ---
# *   `INBOX`: Landing zone for most new mail. Processed quickly.
# *   `Archive`: Single, large archive for processed mail.
# *   `Sent`: Standard sent mail.
# *   `Drafts`: Standard drafts.
# *   `Spam`: Standard spam folder (often managed by server).
# *   `Newsletters`: automated filtering of mailing lists/newsletters via Notmuch.jl rules. Keeps INBOX cleaner.
# *   `Clients/` (Optional Namespace):
#     *   `Clients/ClientA`: Folder for *active* communication regarding ClientA.
#     *   `Clients/ClientB`: Folder for *active* communication regarding ClientB.
#     *   *(Use sparingly - only if strict IMAP separation for ongoing projects/clients is essential. Otherwise, rely on tags within INBOX/Archive)*.



## Conceptual example mails
## for the mail account of an entrepeneur
## who uses notmuch as well as IMAP heavily.

## The example emails illustrate best practice email workflows,
## based on tags (channeling the force of notmuch)
## and clean INBOX folder and structure synchronized with offlineimap.

notmuch_insert(
    rfc_mail(
        "Hello",
        "...";
        from="berta@klum.de",
        to=["me@startup.de"],
        message_id=1
    ),
    folder="INBOX", tags=tag"+client/Klum +lead")
notmuch_insert(
    rfc_mail(
        "Re: Hello";
        from="me@startup.de", to=["berta@klum.de","you@startup.de"],
        in_reply_to=1,
        message_id=2),
    folder="Sent", tags=tag"+client/Klum +todo +waiting +sent")

# --- Client Communication ---

# 1. Initial lead inquiry
notmuch_insert(
    rfc_mail("Inquiry about Service X", "Could you tell me more about..."; from="potential.lead@prospect.net", to=["me@startup.de"], message_id=101),
    folder="INBOX", tags=tag"+lead +unread"
)

# 2. Follow-up to lead
notmuch_insert(
    rfc_mail("Re: Inquiry about Service X", "Thanks for reaching out! Here's more info..."; from="me@startup.de", to=["potential.lead@prospect.net"], in_reply_to=101, message_id=102),
    folder="Sent", tags=tag"+lead +waiting +sent"
)

# 3. Lead converts - becomes client A
notmuch_insert(
    rfc_mail("Re: Inquiry about Service X", "Great, let's proceed!"; from="potential.lead@prospect.net", to=["me@startup.de"], in_reply_to=102, message_id=103),
    folder="INBOX", tags=tag"+client/ClientA +project/Onboarding +todo +unread" # Action needed
)

# 4. Project update request from Client A
notmuch_insert(
    rfc_mail("Project Status Update?", "Hi, any news on the onboarding?"; from="client.a@company.com", to=["me@startup.de"], message_id=104),
    folder="INBOX", tags=tag"+client/ClientA +project/Onboarding +todo +unread"
)

# 5. Sending project update to Client A
notmuch_insert(
    rfc_mail("Re: Project Status Update?", "Update: We've completed task Y..."; from="me@startup.de", to=["client.a@company.com", "team@startup.de"], in_reply_to=104, message_id=105),
    folder="Sent", tags=tag"+client/ClientA +project/Onboarding +sent" # Info sent, maybe waiting tag if reply expected
)

# 6. Meeting request from Client B
notmuch_insert(
    rfc_mail("Meeting Request - Project Zeta", "Can we schedule a call next week?"; from="client.b@another.org", to=["me@startup.de"], message_id=106),
    folder="INBOX", tags=tag"+client/ClientB +project/Zeta +todo +unread"
)

# 7. Confirming meeting with Client B
notmuch_insert(
    rfc_mail("Re: Meeting Request - Project Zeta", "Confirmed for Tuesday 10 AM."; from="me@startup.de", to=["client.b@another.org"], in_reply_to=106, message_id=107),
    folder="Sent", tags=tag"+client/ClientB +project/Zeta +meeting +sent"
)

# 8. Archived thread with Client A after project phase completion
notmuch_insert(
    rfc_mail("Final Report - Onboarding", "Attached is the final report."; from="me@startup.de", to=["client.a@company.com"], message_id=108),
    folder="Archive", tags=tag"+client/ClientA +project/Onboarding +sent +archive" # Moved from Sent to Archive
)

# 9. Quick question from an old client
notmuch_insert(
    rfc_mail("Quick question", "Remember that project from last year...?"; from="old.client@past.co", to=["me@startup.de"], message_id=109),
    folder="INBOX", tags=tag"+client/OldClient +later +unread" # Not urgent
)

# 10. Internal discussion about Client B proposal
notmuch_insert(
    rfc_mail("Thoughts on Client B proposal?", "Need feedback before sending."; from="colleague@startup.de", to=["me@startup.de", "team@startup.de"], message_id=110),
    folder="INBOX", tags=tag"+client/ClientB +project/Zeta +proposal +todo +internal +unread"
)


# --- Newsletters & Subscriptions ---

# 11. Typical marketing newsletter
notmuch_insert(
    rfc_mail("Weekly Tech Insights", "Don't miss our latest articles..."; from="newsletter@tech-updates.com", to=["me@startup.de"], message_id=201, list_id="<tech-updates.lists.com>"),
    folder="Newsletters", tags=tag"+newsletter +archive" # Auto-filtered and archived
)

# 12. SaaS product update newsletter
notmuch_insert(
    rfc_mail("New Features in Tool X!", "Check out what's new this month."; from="updates@saas-tool.io", to=["me@startup.de"], message_id=202, list_unsubscribe="<mailto:unsubscribe@...>"),
    folder="Newsletters", tags=tag"+newsletter +saas +archive"
)

# 13. Unsubscribe confirmation
notmuch_insert(
    rfc_mail("You are unsubscribed", "You will no longer receive emails from..."; from="noreply@annoying-list.org", to=["me@startup.de"], message_id=203),
    folder="Archive", tags=tag"+newsletter +unsubscribed +archive"
)

# 14. Newsletter requiring action (e.g., discount code)
notmuch_insert(
    rfc_mail("Special Offer Just For You!", "Use code SAVE20 by Friday!"; from="deals@marketing.info", to=["me@startup.de"], message_id=204),
    folder="INBOX", tags=tag"+newsletter +offer +todo +unread" # Keep in inbox to act on it
)

# 15. Obscure mailing list traffic
notmuch_insert(
    rfc_mail("[project-dev] Query about legacy API", "Has anyone seen this behavior...?"; from="dev@oss-project.org", to=["project-dev@oss-project.org"], cc=["me@startup.de"], message_id=205, list_id="<project-dev.oss-project.org>"),
    folder="Newsletters", tags=tag"+mailinglist +project/OSS +archive" # Filtered, maybe relevant later
)

# 16. Newsletter from a potentially interesting source
notmuch_insert(
    rfc_mail("Startup Funding Weekly", "Trends in VC funding..."; from="vc-news@capital.io", to=["me@startup.de"], message_id=206),
    folder="INBOX", tags=tag"+newsletter +finance +later +unread" # Review later
)

# 17. Failed unsubscribe attempt (still receiving)
notmuch_insert(
    rfc_mail("We Miss You!", "Come back and see our new offers!"; from="persistent@marketing.net", to=["me@startup.de"], message_id=207),
    folder="Spam", tags=tag"+newsletter +spam" # Marked as spam after failed unsubscribe
)

# 18. Welcome email after signing up for a service/newsletter
notmuch_insert(
    rfc_mail("Welcome to Our Service!", "Thanks for signing up..."; from="welcome@new-saas.com", to=["me@startup.de"], message_id=208),
    folder="Archive", tags=tag"+newsletter +welcome +archive" # Usually just archive
)

# 19. Digest newsletter
notmuch_insert(
    rfc_mail("Daily Digest - Industry News", "Top stories from today..."; from="digest@industry-aggregator.com", to=["me@startup.de"], message_id=209),
    folder="Newsletters", tags=tag"+newsletter +digest +archive"
)

# 20. Personal subscription (e.g., hobby)
notmuch_insert(
    rfc_mail("Photography Club Updates", "Next meeting reminder..."; from="updates@photo-club.org", to=["me@startup.de"], message_id=210),
    folder="Newsletters", tags=tag"+newsletter +personal +hobby +archive"
)

# --- Notifications ---

# 21. GitHub issue notification
notmuch_insert(
    rfc_mail("[org/repo] Issue #123 opened: Bug in login", "..."; from="notifications@github.com", to=["me@startup.de"], message_id=301),
    folder="Archive", tags=tag"+notification +github +project/Repo +archive" # Often auto-archived
)

# 22. CI/CD Build failure
notmuch_insert(
    rfc_mail("Build Failed: project-main #456", "Check logs at..."; from="ci-alerts@buildsystem.startup.de", to=["team@startup.de", "me@startup.de"], message_id=302),
    folder="INBOX", tags=tag"+notification +ci +project/Main +todo +internal +unread" # Actionable
)

# 23. Calendar event reminder
notmuch_insert(
    rfc_mail("Reminder: Meeting with Client B @ Tue 10 AM", "..."; from="calendar-noreply@google.com", to=["me@startup.de"], message_id=303),
    folder="Archive", tags=tag"+notification +calendar +meeting +archive" # Informational, auto-archive
)

# 24. Social media notification (LinkedIn connection request)
notmuch_insert(
    rfc_mail("John Doe wants to connect on LinkedIn", "..."; from="messaging-digest-noreply@linkedin.com", to=["me@startup.de"], message_id=304),
    folder="Archive", tags=tag"+notification +social +linkedin +archive" # Handle on the platform
)

# 25. SaaS tool usage alert
notmuch_insert(
    rfc_mail("Usage Alert: Approaching API limit for Tool X", "..."; from="alerts@saas-tool.io", to=["me@startup.de"], message_id=305),
    folder="INBOX", tags=tag"+notification +saas +billing +todo +unread" # Potential cost implication
)

# 26. Security alert: New login detected
notmuch_insert(
    rfc_mail("Security Alert: New sign-in to your account", "Was this you?"; from="security@important-service.com", to=["me@startup.de"], message_id=306),
    folder="INBOX", tags=tag"+notification +security +todo +urgent +unread" # High priority
)

# 27. Mention in a shared document
notmuch_insert(
    rfc_mail("Jane mentioned you in 'Project Plan'", "..."; from="comments-noreply@docs.google.com", to=["me@startup.de"], message_id=307),
    folder="INBOX", tags=tag"+notification +docs +project/Plan +todo +unread" # Needs attention
)

# 28. Server monitoring alert (resolved)
notmuch_insert(
    rfc_mail("RESOLVED: High CPU on webserver-01", "The issue has been resolved."; from="monitoring@ops.startup.de", to=["team@startup.de", "me@startup.de"], message_id=308),
    folder="Archive", tags=tag"+notification +monitoring +resolved +archive" # Informational, auto-archive
)

# 29. Task assignment notification
notmuch_insert(
    rfc_mail("New Task Assigned: 'Draft Proposal'", "Assigned to you in Project Zeta"; from="tasks@project-manager.app", to=["me@startup.de"], message_id=309),
    folder="INBOX", tags=tag"+notification +tasks +project/Zeta +todo +unread"
)

# 30. Forum mention notification
notmuch_insert(
    rfc_mail("You were mentioned in 'API Best Practices'", "..."; from="forum-noreply@community.dev", to=["me@startup.de"], message_id=310),
    folder="Archive", tags=tag"+notification +forum +community +archive" # Check later if interested
)

# --- Financial ---

# 31. Invoice received from supplier
notmuch_insert(
    rfc_mail("Invoice #INV-789 Due", "Please find attached invoice..."; from="billing@supplier.com", to=["me@startup.de", "accounting@startup.de"], message_id=401),
    folder="INBOX", tags=tag"+finance +invoice +payable +todo +unread"
)

# 32. Invoice sent to client
notmuch_insert(
    rfc_mail("Invoice #STUP-001 for Project Zeta", "Attached is the invoice for..."; from="me@startup.de", to=["client.b@another.org", "accounting@startup.de"], message_id=402),
    folder="Sent", tags=tag"+finance +invoice +receivable +client/ClientB +project/Zeta +sent" # Track payment
)

# 33. Payment confirmation received
notmuch_insert(
    rfc_mail("Payment Received - Thank You!", "We received your payment for Invoice #STUP-001"; from="billing-robot@client-b-finance.org", to=["me@startup.de"], in_reply_to=402, message_id=403),
    folder="Archive", tags=tag"+finance +invoice +receivable +paid +client/ClientB +project/Zeta +archive" # Mark as paid
)

# 34. Bank statement notification
notmuch_insert(
    rfc_mail("Your Monthly Statement is Ready", "Log in to view your statement."; from="noreply@bank.com", to=["me@startup.de"], message_id=404),
    folder="Archive", tags=tag"+finance +bank +statement +archive" # Info, action is external
)

# 35. Payment reminder sent to client
notmuch_insert(
    rfc_mail("Friendly Reminder: Invoice #STUP-001 Overdue", "Just a reminder that..."; from="me@startup.de", to=["client.b@another.org"], in_reply_to=402, message_id=405),
    folder="Sent", tags=tag"+finance +invoice +receivable +client/ClientB +project/Zeta +reminder +sent"
)

# 36. Expense report submission confirmation
notmuch_insert(
    rfc_mail("Expense Report Submitted", "Your report #EXP-012 has been received."; from="expenses@hr-tool.startup.de", to=["me@startup.de"], message_id=406),
    folder="Archive", tags=tag"+finance +expenses +internal +archive"
)

# 37. Credit card charge notification
notmuch_insert(
    rfc_mail("Charge Notification: \$50.00 at SAAS-TOOL.IO", "A charge was made..."; from="alerts@credit-card.com", to=["me@startup.de"], message_id=407),
    folder="Archive", tags=tag"+finance +cc +notification +archive"
)

# 38. Query about an invoice from accounting
notmuch_insert(
    rfc_mail("Query re: Invoice #INV-789", "Can you confirm this charge?"; from="accountant@startup.de", to=["me@startup.de"], in_reply_to=401, message_id=408),
    folder="INBOX", tags=tag"+finance +invoice +payable +todo +internal +unread"
)

# 39. Tax document notification
notmuch_insert(
    rfc_mail("Important Tax Document Available", "Your Form 1099 is ready."; from="noreply@tax-service.com", to=["me@startup.de"], message_id=409),
    folder="INBOX", tags=tag"+finance +tax +todo +important +unread"
)

# 40. Budget discussion thread
notmuch_insert(
    rfc_mail("Q3 Budget Planning", "Let's discuss the draft budget."; from="cfo@startup.de", to=["me@startup.de", "team@startup.de"], message_id=410),
    folder="INBOX", tags=tag"+finance +budget +planning +internal +todo +unread"
)

# --- Personal & Miscellaneous ---

# 41. Email from a friend
notmuch_insert(
    rfc_mail("Catch up soon?", "Hey, how are things? Free next week?"; from="friend@personal.com", to=["me@startup.de"], message_id=501),
    folder="INBOX", tags=tag"+personal +social +later +unread"
)

# 42. Travel confirmation
notmuch_insert(
    rfc_mail("Your Flight Confirmation - NYC", "Booking Ref: XYZ123"; from="bookings@airline.com", to=["me@startup.de"], message_id=502),
    folder="Archive", tags=tag"+personal +travel +confirmation +archive"
)

# 43. Online order shipment notification
notmuch_insert(
    rfc_mail("Your Order #9876 has Shipped!", "Tracking number: 1Z..."; from="shipping@retailer.com", to=["me@startup.de"], message_id=503),
    folder="Archive", tags=tag"+personal +shopping +shipping +archive"
)

# 44. Draft email to colleague (incomplete)
notmuch_insert(
    rfc_mail("Ideas for Q3 marketing", "My initial thoughts are:\n- ..."; from="me@startup.de", to=["marketing-colleague@startup.de"], message_id=504),
    folder="Drafts", tags=tag"+draft +internal +marketing"
)

# 45. Sent personal email
notmuch_insert(
    rfc_mail("Re: Catch up soon?", "Yeah, Tuesday evening works!"; from="me@startup.de", to=["friend@personal.com"], in_reply_to=501, message_id=505),
    folder="Sent", tags=tag"+personal +social +sent"
)

# 46. Appointment reminder (doctor)
notmuch_insert(
    rfc_mail("Appointment Reminder: Dr. Smith", "Tomorrow at 3 PM."; from="appointments@clinic.com", to=["me@startup.de"], message_id=506),
    folder="Archive", tags=tag"+personal +health +appointment +archive"
)

# 47. Automated system message (e.g., quota warning)
notmuch_insert(
    rfc_mail("Mailbox Quota Warning", "Your mailbox is 90% full."; from="postmaster@startup.de", to=["me@startup.de"], message_id=507),
    folder="INBOX", tags=tag"+system +admin +todo +unread"
)

# --- Spam ---

# 48. Obvious phishing attempt
notmuch_insert(
    rfc_mail("Urgent: Verify Your Account Now!", "Click here to prevent account suspension..."; from="security-update@totally-legit-bank.com", to=["me@startup.de"], message_id=601),
    folder="Spam", tags=tag"+spam +phishing" # Hopefully caught by spam filter
)

# 49. Unsolicited commercial email (junk)
notmuch_insert(
    rfc_mail("Buy Cheap Widgets!", "Best prices guaranteed!"; from="sales@spam-widgets.biz", to=["random-list@listserv.nodomain"], bcc=["me@startup.de"], message_id=602),
    folder="Spam", tags=tag"+spam +junk"
)

# 50. Foreign language spam
notmuch_insert(
    rfc_mail("=?UTF-8?B?5L2g5aW96ZmQ?=", "..."; from="foreign.spammer@overseas.cn", to=["me@startup.de"], message_id=603),
    folder="Spam", tags=tag"+spam"
)

# 51. Malformed header spam
notmuch_insert(
    rfc_mail(" Undisclosed recipients", ""; from="<MAILER-DAEMON>", to=[], message_id=604), # Malformed 'From'
    folder="Spam", tags=tag"+spam"
)

# 52. Follow up on client A onboarding - mark original as done
notmuch_insert(
    rfc_mail("Re: Project Status Update?", "Thanks for the update!"; from="client.a@company.com", to=["me@startup.de"], in_reply_to=105, message_id=111),
    folder="INBOX", tags=tag"+client/ClientA +project/Onboarding +waiting +unread" # Now waiting on *them* perhaps? Or just archive.
    # Assume rule `tag -todo -unread id:104` was applied when #105 was sent.
    # Now apply `tag -waiting +archive id:111` and `tag +archive id:105`
)

# 53. Internal mail needing discussion later
notmuch_insert(
    rfc_mail("Long term strategy brainstorm", "Some initial thoughts for discussion..."; from="ceo@startup.de", to=["team@startup.de", "me@startup.de"], message_id=701),
    folder="INBOX", tags=tag"+internal +strategy +later +unread"
)



# --- Base Setup ---
# Assuming user: me@startup.de
# Assuming partner: partner@startup.de

# --- Client Communication: Acme Corp ---
notmuch_insert(rfc_mail("Project Alpha Kick-off", "Excited to start!", from="ceo@acme.com", to=["me@startup.de"], message_id=101), folder="INBOX", tags=tag"+client/Acme +project/Alpha +lead +unread")
notmuch_insert(rfc_mail("Re: Project Alpha Kick-off", "Agenda proposal attached.", from="me@startup.de", to=["ceo@acme.com", "partner@startup.de"], in_reply_to=101, message_id=102), folder="Sent", tags=tag"+client/Acme +project/Alpha +sent +waiting")
notmuch_insert(rfc_mail("Re: Project Alpha Kick-off", "Agenda looks good. Can we add a point about budget?", from="ceo@acme.com", to=["me@startup.de"], references=[101], message_id=103), folder="INBOX", tags=tag"+client/Acme +project/Alpha +todo +unread")
notmuch_insert(rfc_mail("Re: Project Alpha Kick-off", "Updated agenda including budget discussion.", from="me@startup.de", to=["ceo@acme.com"], in_reply_to=103, references=[101], message_id=104), folder="Sent", tags=tag"+client/Acme +project/Alpha +sent") # Waiting implied by thread context
notmuch_insert(rfc_mail("Weekly Status Report - Project Alpha W1", "Summary of progress.", from="partner@startup.de", to=["me@startup.de", "ceo@acme.com"], message_id=105), folder="Sent", tags=tag"+client/Acme +project/Alpha +sent") # Sent by partner, I'm CC'd
notmuch_insert(rfc_mail("Draft Proposal for Phase 2", "Please review internally.", from="me@startup.de", to=["partner@startup.de"], message_id=106), folder="Drafts", tags=tag"+client/Acme +project/Alpha +draft +proposal")
notmuch_insert(rfc_mail("Proposal for Project Alpha Phase 2", "Attached is our proposal.", from="me@startup.de", to=["ceo@acme.com"], message_id=107), folder="Sent", tags=tag"+client/Acme +project/Alpha +sent +proposal +waiting")
notmuch_insert(rfc_mail("Re: Proposal for Project Alpha Phase 2", "Thanks, we'll review and get back next week.", from="ceo@acme.com", to=["me@startup.de"], in_reply_to=107, message_id=108), folder="INBOX", tags=tag"+client/Acme +project/Alpha +proposal +unread") # Tagged for context, waiting state remains on thread
notmuch_insert(rfc_mail("Invoice #INV-001 - Project Alpha", "Phase 1 complete.", from="me@startup.de", to=["accounts@acme.com", "ceo@acme.com"], message_id=109), folder="Sent", tags=tag"+client/Acme +project/Alpha +sent +invoice +finance +waiting")
notmuch_insert(rfc_mail("Payment Confirmation for INV-001", "Payment processed.", from="accounts@acme.com", to=["me@startup.de"], in_reply_to=109, message_id=110), folder="Archive", tags=tag"+client/Acme +project/Alpha +invoice +finance") # Processed, archived directly

# --- Client Communication: Beta Corp (Smaller project) ---
notmuch_insert(rfc_mail("Quick Question about API integration", "...", from="dev@betacorp.org", to=["me@startup.de"], message_id=201), folder="INBOX", tags=tag"+client/BetaCorp +project/Integration +todo +unread")
notmuch_insert(rfc_mail("Re: Quick Question about API integration", "Here's the documentation link...", from="me@startup.de", to=["dev@betacorp.org"], in_reply_to=201, message_id=202), folder="Sent", tags=tag"+client/BetaCorp +project/Integration +sent") # Simple answer, archived implicitly
notmuch_insert(rfc_mail("Follow up: API integration", "All working now, thanks!", from="dev@betacorp.org", to=["me@startup.de"], in_reply_to=202, references=[201], message_id=203), folder="Archive", tags=tag"+client/BetaCorp +project/Integration") # No action needed

# --- Internal Project Communication: Website Revamp ---
notmuch_insert(rfc_mail("Ideas for new website design", "...", from="partner@startup.de", to=["me@startup.de"], message_id=301), folder="INBOX", tags=tag"+project/WebsiteRevamp +later +unread")
notmuch_insert(rfc_mail("Task: Draft Homepage Content", "Assigning this to you.", from="partner@startup.de", to=["me@startup.de"], message_id=302), folder="INBOX", tags=tag"+project/WebsiteRevamp +todo +unread")
notmuch_insert(rfc_mail("Re: Task: Draft Homepage Content", "Working on it, aiming for EOD Friday.", from="me@startup.de", to=["partner@startup.de"], in_reply_to=302, message_id=303), folder="Sent", tags=tag"+project/WebsiteRevamp +sent")
notmuch_insert(rfc_mail("Website Content Draft", "Attached.", from="me@startup.de", to=["partner@startup.de"], message_id=304), folder="Sent", tags=tag"+project/WebsiteRevamp +sent +waiting") # Waiting for feedback
notmuch_insert(rfc_mail("Re: Website Content Draft", "Looks great, minor tweaks suggested.", from="partner@startup.de", to=["me@startup.de"], in_reply_to=304, message_id=305), folder="INBOX", tags=tag"+project/WebsiteRevamp +todo +unread")

# --- Technical / Development ---
notmuch_insert(rfc_mail("Bug Report: Login fails on Safari", "...", from="qa@startup.de", to=["me@startup.de", "partner@startup.de"], message_id=401), folder="INBOX", tags=tag"+project/BackendAPI +bug +todo +unread")
notmuch_insert(rfc_mail("[CI] Build Failed: project/BackendAPI main #123", "Error details...", from="ci-bot@startup.de", to=["dev-alerts@startup.de"], message_id=402), folder="INBOX", tags=tag"+project/BackendAPI +notification +ci +todo +unread") # Assuming I'm subscribed to dev-alerts
notmuch_insert(rfc_mail("[CI] Build Success: project/BackendAPI main #124", "...", from="ci-bot@startup.de", to=["dev-alerts@startup.de"], message_id=403), folder="Archive", tags=tag"+project/BackendAPI +notification +ci") # Auto-archived or quickly processed
notmuch_insert(rfc_mail("Github Dependabot Alert: Upgrade lodash", "Security vulnerability...", from="notifications@github.com", to=["me@startup.de"], message_id=404), folder="INBOX", tags=tag"+project/WebsiteRevamp +notification +dependency +later +unread")
notmuch_insert(rfc_mail("[julia-users] Question about Precompilation", "...", from="newbie@example.com", to=["julia-users@googlegroups.com"], message_id=405), folder="Newsletters", tags=tag"+list/julia-users +unread") # Filtered to Newsletters
notmuch_insert(rfc_mail("Re: [julia-users] Question about Precompilation", "You should try...", from="expert@example.com", to=["julia-users@googlegroups.com"], in_reply_to=405, message_id=406), folder="Newsletters", tags=tag"+list/julia-users +unread")
notmuch_insert(rfc_mail("Server Monitoring Alert: High CPU Load", "Server xyz experiencing high load.", from="monitoring@startup.de", to=["me@startup.de"], message_id=407), folder="INBOX", tags=tag"+notification +server +todo +unread")
notmuch_insert(rfc_mail("Code Review Request: Feature Branch xyz", "Please review PR #56.", from="partner@startup.de", to=["me@startup.de"], message_id=408), folder="INBOX", tags=tag"+project/BackendAPI +codereview +todo +unread")
notmuch_insert(rfc_mail("Re: Code Review Request: Feature Branch xyz", "LGTM, just one minor comment.", from="me@startup.de", to=["partner@startup.de"], in_reply_to=408, message_id=409), folder="Sent", tags=tag"+project/BackendAPI +codereview +sent")

# --- Finance / Admin ---
notmuch_insert(rfc_mail("Your SaaS Subscription Invoice", "Invoice #SaaS-456 attached.", from="billing@saas.com", to=["me@startup.de"], message_id=501), folder="INBOX", tags=tag"+finance +invoice +todo +unread") # Need to pay or record
notmuch_insert(rfc_mail("Monthly Bank Statement Available", "Log in to view.", from="bank@secure.com", to=["me@startup.de"], message_id=502), folder="Archive", tags=tag"+finance +bank") # Informational, archived
notmuch_insert(rfc_mail("Tax Filing Deadline Reminder", "...", from="tax-advisor@example.com", to=["me@startup.de", "partner@startup.de"], message_id=503), folder="INBOX", tags=tag"+finance +tax +todo +unread")
notmuch_insert(rfc_mail("Domain Name Renewal Notice: startup.de", "Expires in 30 days.", from="registrar@example.net", to=["admin@startup.de"], message_id=504), folder="INBOX", tags=tag"+finance +admin +todo +unread") # Assuming I check admin@
notmuch_insert(rfc_mail("Receipt for your recent order", "Order #12345", from="store@example.com", to=["me@startup.de"], message_id=505), folder="Archive", tags=tag"+finance +receipt") # Keep for records

# --- Networking / Leads ---
notmuch_insert(rfc_mail("Following up from Conf XYZ", "Great chatting with you!", from="potential-partner@example.com", to=["me@startup.de"], message_id=601), folder="INBOX", tags=tag"+lead +conference +todo +unread")
notmuch_insert(rfc_mail("Re: Following up from Conf XYZ", "Likewise! Let's schedule a call.", from="me@startup.de", to=["potential-partner@example.com"], in_reply_to=601, message_id=602), folder="Sent", tags=tag"+lead +conference +sent +waiting")
notmuch_insert(rfc_mail("Introduction Request: You <> Jane Doe", "Can you introduce me?", from="contact@example.org", to=["me@startup.de"], message_id=603), folder="INBOX", tags=tag"+networking +todo +unread")
notmuch_insert(rfc_mail("Fwd: Potential Candidate for Dev Role", "FYI - from LinkedIn", from="recruiter@example.net", to=["me@startup.de", "partner@startup.de"], message_id=604), folder="INBOX", tags=tag"+recruiting +lead +later +unread")

# --- Personal ---
notmuch_insert(rfc_mail("Weekend Plans?", "...", from="friend@example.com", to=["me@startup.de"], message_id=701), folder="INBOX", tags=tag"+personal +later +unread")
notmuch_insert(rfc_mail("Family Dinner Sunday?", "...", from="mom@example.com", to=["me@startup.de"], message_id=702), folder="INBOX", tags=tag"+personal +todo +unread")
notmuch_insert(rfc_mail("Re: Weekend Plans?", "Sounds fun!", from="me@startup.de", to=["friend@example.com"], in_reply_to=701, message_id=703), folder="Sent", tags=tag"+personal +sent") # Archived implicitly

# --- Newsletters / Marketing ---
notmuch_insert(rfc_mail("Weekly Tech Digest Vol. 42", "Top stories...", from="newsletter@techweekly.com", to=["me@startup.de"], message_id=801), folder="Newsletters", tags=tag"+newsletter +tech +unread") # Filtered automatically
notmuch_insert(rfc_mail("Startup Growth Hacks #15", "...", from="growth@marketingbuzz.com", to=["me@startup.de"], message_id=802), folder="Newsletters", tags=tag"+newsletter +marketing +unread")
notmuch_insert(rfc_mail("Product Hunt Daily Digest", "...", from="digest@producthunt.com", to=["me@startup.de"], message_id=803), folder="Newsletters", tags=tag"+newsletter +product +unread")
notmuch_insert(rfc_mail("Competitor XYZ Funding Announcement", "...", from="news-alert@example.com", to=["me@startup.de"], message_id=804), folder="Newsletters", tags=tag"+newsletter +competitor +later +unread")

# --- Miscellaneous & Edge Cases ---
notmuch_insert(rfc_mail("Re: Quick Question (was: Old Thread Subject)", "Following up on our chat...", from="clientA@example.com", to=["me@startup.de"], message_id=901), folder="INBOX", tags=tag"+client/Acme +todo +unread") # Subject changed but still relevant
notmuch_insert(rfc_mail("Meeting Invitation: Project Sync", "...", from="calendar@startup.de", to=["me@startup.de", "partner@startup.de"], message_id=902), folder="Archive", tags=tag"+calendar +notification") # Calendar invites often auto-processed
notmuch_insert(rfc_mail("Your account password has been reset", "If you did not request this...", from="security@service.com", to=["me@startup.de"], message_id=903), folder="INBOX", tags=tag"+security +notification +todo +unread")
notmuch_insert(rfc_mail("(no subject)", "sent from my phone", from="me@startup.de", to=["partner@startup.de"], message_id=904), folder="Sent", tags=tag"+sent") # Minimal mail
notmuch_insert(rfc_mail("Undeliverable: Your message to nonexistant@example.com", "...", from="MAILER-DAEMON@mailserver.com", to=["me@startup.de"], message_id=905), folder="INBOX", tags=tag"+bounce +notification +todo +unread")
notmuch_insert(rfc_mail("Happy Birthday!", "...", from="hr@startup.de", to=["all@startup.de"], message_id=906), folder="Archive", tags=tag"+company +personal") # Internal fluff
notmuch_insert(rfc_mail("Vacation request approved", "...", from="hr-system@startup.de", to=["me@startup.de"], message_id=907), folder="Archive", tags=tag"+hr +notification")
notmuch_insert(rfc_mail("Draft: Blog post announcement", "...", from="me@startup.de", to=[], message_id=908), folder="Drafts", tags=tag"+draft +marketing")


using Notmuch
using JSON3
using Test

# --- Setup Temporary Notmuch Environment ---
home = tempname()
mkdir(home)
ENV["NOTMUCH_WD"] = home
ENV["NOMAILDIR"] = "mail" # Relative to NOTMUCH_WD
ENV["NOHOME"] = home # Just to be sure if HOME is used internally
notmuch_setup(name="Founder", primary_email="me@startup.de")

@testset "Initial Setup" begin
    @test notmuch_count() == 0
    # Create standard folders implicitly used later
    mkpath(joinpath(home, "mail", "INBOX"))
    mkpath(joinpath(home, "mail", "Sent"))
    mkpath(joinpath(home, "mail", "Drafts"))
    mkpath(joinpath(home, "mail", "Archive"))
    mkpath(joinpath(home, "mail", "Newsletters"))
    mkpath(joinpath(home, "mail", "Spam"))
end

@testset "Founder Email Workflow Examples" begin

    # 1. Incoming Client Inquiry (Lead)
    # Initially lands in INBOX, tagged as unread, lead, and with client context.
    notmuch_insert(
        rfc_mail(
            "Inquiry about Widget X",
            "Dear Founder, we are interested in learning more about Widget X...";
            from="potential.client@example.com",
            to=["me@startup.de"],
            message_id="<inquiry_1@example.com>"
        ),
        folder="INBOX",
        tags=tag"+inbox +unread +lead +client/PotentialClient"
    )

    # 2. Reply to Client (Proposal Sent)
    # Sent mail, tagged as waiting for response, related to proposal and client.
    notmuch_insert(
        rfc_mail(
            "Re: Inquiry about Widget X",
            "Hi Potential Client, please find our proposal attached...";
            from="me@startup.de",
            to=["potential.client@example.com"],
            in_reply_to="<inquiry_1@example.com>",
            message_id="<reply_prop_2@startup.de>"
        ),
        folder="Sent",
        tags=tag"+sent +waiting +proposal +client/PotentialClient"
    )

    # 3. Internal Discussion/Delegation
    # Forwarding for internal action, tagged appropriately.
    notmuch_insert(
        rfc_mail(
            "Fwd: Inquiry about Widget X - Can you handle initial contact?",
            "Team, could someone follow up on this lead? Thanks.";
            from="me@startup.de",
            to=["colleague@startup.de"],
            references="<inquiry_1@example.com>",
            message_id="<internal_fwd_3@startup.de>"
        ),
        folder="Sent",
        tags=tag"+sent +delegated +client/PotentialClient"
    )

    # 4. Invoice Received (Service Provider)
    # Lands in INBOX, tagged for finance processing (todo: pay).
    # (Post-processing hook/action would retag +paid, -todo, -inbox and move to Archive)
    notmuch_insert(
        rfc_mail(
            "Invoice #INV-123 for Cloud Services",
            "Your monthly invoice for cloud services is attached.";
            from="billing@cloudprovider.com",
            to=["me@startup.de"],
            message_id="<invoice_recv_4@cloudprovider.com>"
        ),
        folder="INBOX",
        tags=tag"+inbox +unread +finance +invoice +todo"
    )

    # 5. Invoice Sent (To Client)
    # Sent mail, tagged for finance tracking (waiting for payment).
    notmuch_insert(
        rfc_mail(
            "Invoice #INV-001 for Project Y",
            "Dear Client, please find attached invoice INV-001 for Project Y.";
            from="me@startup.de",
            to=["client.contact@example.com"],
            message_id="<invoice_sent_5@startup.de>"
        ),
        folder="Sent",
        tags=tag"+sent +finance +invoice +waiting +client/ClientX"
    )

    # 6. Newsletter/Notification
    # Ideally, a pre-new hook would file this directly into 'Newsletters' and tag it.
    # Simulating post-receipt processing: Inserted to INBOX first, then assume a rule runs.
    notmuch_insert(
        rfc_mail(
            "Weekly Tech News Roundup",
            "This week in tech: AI breakthroughs, market trends...";
            from="newsletter@techfeed.com",
            to=["me@startup.de"],
            message_id="<newsletter_6@techfeed.com>"
        ),
        folder="INBOX", # Simulates arrival before rules run
        tags=tag"+inbox +unread" # Initial tags
    )
    # Simulate rule: mv Newsletters INBOX from:newsletter@techfeed.com AND tag +newsletter +later -inbox -unread from:newsletter@techfeed.com
    let msg_id = "id:" * Notmuch.escape_id("<newsletter_6@techfeed.com>")
        @apply MailsRule(mv"INBOX Newsletters", msg_id)
        @apply MailsRule(tag"+newsletter +later -inbox -unread", msg_id)
    end


    # 7. Personal Mail
    # Lands in INBOX, tagged personal. Processed and archived later.
    notmuch_insert(
        rfc_mail(
            "Weekend plans?",
            "Hey, free this weekend for a hike?";
            from="friend@personal.net",
            to=["me@startup.de"],
            message_id="<personal_7@personal.net>"
        ),
        folder="INBOX",
        tags=tag"+inbox +unread +personal"
    )

    # 8. Draft Being Worked On
    # Stored in Drafts, tagged draft and todo (finish it).
    notmuch_insert(
        rfc_mail(
            "[DRAFT] Strategy Doc Outline",
            " পয়েন্ট ১: বাজার বিশ্লেষণ\n পয়েন্ট ২: মূল পার্থক্যকারী\n..."; # Example with Unicode
            from="me@startup.de",
            # To might be added later
            message_id="<draft_8@startup.de.local>" # Local draft ID
        ),
        folder="Drafts",
        tags=tag"+draft +todo"
    )

    # --- Verification Tests ---
    @test notmuch_count("tag:inbox") == 3 # Inquiry, Invoice Recv, Personal
    @test notmuch_count("tag:sent") == 3  # Reply, Internal Fwd, Invoice Sent
    @test notmuch_count("tag:draft") == 1
    @test notmuch_count("tag:newsletter") == 1
    @test notmuch_count("tag:client/PotentialClient") == 3
    @test notmuch_count("tag:finance") == 2
    @test notmuch_count("tag:todo") == 2 # Invoice Recv, Draft
    @test notmuch_count("tag:waiting") == 2 # Reply, Invoice Sent
    @test notmuch_count("folder:INBOX") == 2 # Invoice Recv, Personal (Inquiry moved conceptually, Newsletter moved by rule)
    # Correction: Inquiry is still in INBOX as no rule moved it.
    @test notmuch_count("folder:INBOX") == 3 # Inquiry, Invoice Recv, Personal
    @test notmuch_count("folder:Sent") == 3
    @test notmuch_count("folder:Drafts") == 1
    @test notmuch_count("folder:Newsletters") == 1
    @test notmuch_count("folder:Archive") == 0 # Nothing archived yet

    # Test retrieval of a specific mail
    let emails = Email.(notmuch_ids("id:\"<invoice_recv_4@cloudprovider.com>\""))
        @test length(emails) == 1
        e = emails[1]
        @test e.headers.Subject == "Invoice #INV-123 for Cloud Services"
        @test "finance" in e.tags
        @test "todo" in e.tags
        @test "inbox" in e.tags
        @test startswith(e.files[1], joinpath(home, "mail", "INBOX"))
    end

    let emails = Email.(notmuch_ids("id:\"<newsletter_6@techfeed.com>\""))
         @test length(emails) == 1
         e = emails[1]
         @test "newsletter" in e.tags
         @test "later" in e.tags
         @test !("inbox" in e.tags)
         @test startswith(e.files[1], joinpath(home, "mail", "Newsletters"))
     end

end












# --- Example Rules (Illustrative) ---

# Rule Definitions using Notmuch.jl syntax

# 1. Initial Triage & Categorization (Applied manually or via notmuch hooks)
#    - Tag mail from known clients

rule_client_acme = rule"tag +client/Acme from:ceo@acme.com or from:contact@acme.com"
#    - Tag potential leads based on subject or sender
rule_lead_gen = rule"tag +lead subject:'Inquiry about' or from:leads@partner.org"
#    - Tag financial documents
rule_finance = rule"tag +finance tag +invoice subject:'Invoice' or subject:'Receipt'"
#    - Tag newsletters (using List-Id header is robust)
rule_newsletter = rule"tag +newsletter header:List-Id:/newsletter/"
#    - Tag internal team communication
rule_team = rule"tag +team to:team@mycompany.com"

# 2. Action & Workflow Management (Often applied manually during review)
#    - Mark items needing direct action
#      (Manual: Select emails, then `@apply tag"+todo" tag"-inbox"`)
#    - Mark items waiting for a reply
#      (Manual: Select email sent, then `@apply tag"+waiting"`)
#    - Defer items for later review
#      (Manual: Select email, then `@apply tag"+later" tag"-inbox"`)

# 3. Cleanup & Archiving Rules (Can be run periodically)
#    - Archive processed mail (no longer in inbox, not needing action/waiting)
rule_archive_processed = rule"tag +archive tag -inbox not tag:todo and not tag:waiting and not tag:draft"
#    - Maybe move archived mail physically (if desired alongside tags)
rule_move_archived = rule"mv INBOX Archive tag:archive and folder:INBOX"
#    - Remove 'waiting' tag if a reply is received (simplistic example)
#      (More complex logic might be needed, potentially external scripting)
# rule_clear_waiting = rule"tag -waiting thread:{ tag:waiting and tag:unread and not tag:sent }" # Conceptual

# 4. Drafts and Sent Mail (Often handled by Mail Client Integration or hooks)
#    - Ensure drafts are tagged and in the right folder
rule_drafts = rule"tag +draft folder:Drafts"
#    - Ensure sent mail is tagged and in the right folder
rule_sent = rule"tag +sent folder:Sent"


# --- Applying Rules (Example) ---
# Assume you have emails indexed. You might apply rules like this:

# @apply rule_client_acme  # Apply specific rule to all matching mail
# @apply rule_finance

# Or apply during manual review based on a query:
# emails_to_archive = notmuch_search("tag:inbox and not tag:unread and not tag:todo")
# notmuch_tag(tag"-inbox", tag"+archive", emails_to_archive) # Using lower-level functions

using REPL.TerminalMenus
using Notmuch

# --- Core Functionality ---

"""
    select_mail(query::String="tag:inbox and tag:unread"; prompt::String="Select mail:") -> Vector{String}

Interactively select emails matching `query` in the REPL.
Returns a vector of selected message IDs.
"""
function select_mail(query::String="tag:inbox and tag:unread"; prompt::String="Select mail:")
    ids = notmuch_ids(query)
    isempty(ids) && return String[]

    # Fetch minimal info for display (e.g., Date, From, Subject)
    # Using `notmuch show` might be slightly faster for bulk display than reconstructing Emails
    # but requires parsing. Let's use Email objects for simplicity here.
    # Consider `notmuch search --output=messages --format=json` for more structured data
    # if performance becomes an issue with many results.
    emails = Email.(ids) # Potentially slow for very large result sets

    # Format options for the menu
    options = map(emails) do e
        subj = get(e.headers, :Subject, "[no subject]")
        from = get(e.headers, :From, "[no sender]")
        # Basic date formatting (customize as needed)
        date_str = Dates.format(e.date, "yyyy-mm-dd HH:MM")
        # Truncate long subjects/senders for display
        max_len = 60
        subj_trunc = length(subj) > max_len ? subj[1:max_len-1] * "…" : subj
        from_trunc = length(from) > max_len ? from[1:max_len-1] * "…" : from
        "$date_str | $(rpad(from_trunc, max_len)) | $subj_trunc"
    end

    # Use MultiSelectMenu
    menu = MultiSelectMenu(options; Crayon(foreground = :green), pagesize=10)
    selected_indices = request(prompt, menu)

    if isempty(selected_indices)
        return String[]
    else
        return ids[sort(collect(selected_indices))] # Return selected message IDs
    end
end

# --- Example Usage & Workflow Integration ---

# 1. Select unread mail in the inbox
selected_ids = select_mail()

if !isempty(selected_ids)
    println("\nYou selected:")
    # Display details of selected messages (optional)
    for id in selected_ids
        try
            e = Email(id)
            println("- ID: ", e.id)
            println("  Subject: ", get(e.headers, :Subject, "[no subject]"))
            println("  From: ", get(e.headers, :From, "[no sender]"))
        catch err
             @error "Could not load email for ID $id" error=err
        end
    end

    # 2. Offer actions for the selected emails
    actions = ["Tag +todo -inbox", "Tag +later -inbox", "Tag +archive -inbox", "Mark as read (-unread)", "Custom tag..."]
    action_menu = RadioMenu(actions; pagesize=5)
    chosen_action_idx = request("\nApply action to selected emails:", action_menu)

    if chosen_action_idx != -1
        action_str = actions[chosen_action_idx]
        tags_to_apply = Notmuch.TagChange[]

        if action_str == "Custom tag..."
            print("Enter tags (e.g., +work -urgent): ")
            custom_tags_str = readline()
            try
                 tags_to_apply = Notmuch.parsetags(custom_tags_str)
            catch e
                @error "Invalid tag format: $custom_tags_str" error=e
                tags_to_apply = [] # Prevent applying invalid tags
            end
        else
            # Parse standard actions
            tags_to_apply = Notmuch.parsetags(split(action_str)[2:end]...) # Extract tags like "+todo", "-inbox"
        end

        if !isempty(tags_to_apply)
            try
                notmuch_tag(tags_to_apply..., selected_ids)
                println("Applied: ", join(string.(tags_to_apply), " "), " to ", length(selected_ids), " emails.")
            catch err
                @error "Failed to apply tags" error=err
            end
        elseif action_str != "Custom tag..." # Only print error if it wasn't a failed custom input
             @warn "No valid tags selected for action."
        end
    else
        println("No action taken.")
    end
else
    println("No emails selected or found matching the query.")
end

# --- Implementation Outline ---
#
# 1.  **Query Function (`notmuch_ids`):**
#     *   Use `Notmuch.notmuch_ids(query_string)` to get a list of message IDs matching the user's search criteria (e.g., "tag:inbox and tag:unread").
#
# 2.  **Data Fetching (`Email` constructor or `notmuch show`):**
#     *   For each ID retrieved, fetch essential information for display (Subject, From, Date).
#     *   Using `Email(id)` is convenient but might load the entire email file.
#     *   Alternatively, use `notmuch show --format=json --part=0 id...` or `notmuch search --format=text --output=messages query...` for more targeted data fetching, which requires parsing the output but can be faster for many results.
#
# 3.  **Display Formatting:**
#     *   Format the fetched data (Date, From, Subject) into concise, aligned strings suitable for a menu line. Truncate long fields.
#
# 4.  **Interactive Selection (`REPL.TerminalMenus`):**
#     *   Use `TerminalMenus.MultiSelectMenu` to present the formatted email list to the user.
#         *   Pass the formatted strings as `options`.
#         *   Configure `pagesize` for reasonable scrolling.
#         *   Customize appearance (e.g., `Crayon`).
#     *   Use `TerminalMenus.request(prompt, menu)` to display the menu and capture the user's selection (indices of chosen items).
#
# 5.  **Result Handling:**
#     *   Map the selected indices back to the original `notmuch_ids`.
#     *   Return the vector of selected message IDs.
#
# 6.  **Workflow Integration (Example):**
#     *   Call `select_mail` with a desired query.
#     *   Check if any IDs were returned.
#     *   (Optional) Display details of the selected emails.
#     *   Present further actions using `TerminalMenus.RadioMenu` (e.g., tagging, moving).
#     *   Use `Notmuch.notmuch_tag` or `Notmuch.apply_rule` based on the chosen action and the selected IDs.
#
# --- Tips & Best Practices ---
#
# *   **Performance:** For queries returning thousands of results, loading full `Email` objects can be slow. Consider `notmuch search --format=json` and `JSON3.read` for faster display data retrieval.
# *   **Error Handling:** Wrap `Notmuch` calls and `Email` loading in `try...catch` blocks to handle potential errors (e.g., missing files, invalid IDs).
# *   **Modularity:** Separate the UI selection logic (`select_mail`) from the action logic (tagging, moving) for better code organization.
# *   **User Experience:** Provide clear prompts. Consider adding features like previewing email content within the selection loop or refining the search query interactively. Use paging (`pagesize`) effectively.
# *   **Dependencies:** Ensure `REPL` (for `TerminalMenus`) is available. It's part of Julia's standard library.
```
