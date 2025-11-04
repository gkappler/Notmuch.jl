# file: src/EmailEvent.jl  (new; in Notmuch.jl or a small companion module)

module EmailUI

using ..Notmuch
using ..Notmuch: Email, notmuch_ids, query_parser, render
using Dates
using AgentTeams.UI  

mutable struct EmailMessageEvent{EventType}
    id::String
    email::Union{Email,Nothing}
    thread::Union{String,Nothing}
    is_retry::Bool
end

const DEFAULT_EMAIL_EVENT_RULES = [
    (e -> in("spam", e.tags))                   => :SpamMessageEvent,
    (e -> in("draft", e.tags))                  => :DraftMessageEvent,
    (e -> in("queued", e.tags) &&
           any(f -> occursin("/Outbox/", f) || occursin("/Outbox", f), e.filename)) => :QueuedMessageEvent,
    (e -> in("sent", e.tags))                   => :SentMessageEvent,
    (e -> in("inbox", e.tags) ||
           any(f -> occursin("/INBOX", f), e.filename)) => :InboundMessageEvent,
    (_ -> true)                                 => :UnknownEvent,
]

function parse_email_event(id::AbstractString; rules=DEFAULT_EMAIL_EVENT_RULES, kw...)
    e = try
        Email(id; body=false, kw...)
    catch
        nothing
    end
    event_type = :UnknownEvent
    if e !== nothing
        for (pred, typ) in rules
            try
                if pred(e)
                    event_type = typ; break
                end
            catch
                # ignore predicate errors
            end
        end
    end
    EmailMessageEvent{event_type}(String(id), e, e === nothing ? nothing : e.id, false)
end
macro process_email_event(event_type, body)
    quote
        function process_event(h::EmailUI.EmailMessageEvent{$(QuoteNode(event_type))}, ctx...; kw...)
            $(body)
        end
    end
end
# Minimal UI hooks to integrate with AgentTeams.UI:
# - update_status!: insert a small status note into the same thread and/or tag
# - send_final_response!: similar (optional)
# - event_id: stable ID for persistence
end


module EmailAgentUI

using ..Notmuch
using ..Notmuch: rfc_mail, notmuch_insert, notmuch_tag, query_parser
using ..EmailUI: EmailMessageEvent
using AgentTeams.UI
import AgentTeams.UI: event_id, update_status!, send_final_response!

# Stable id: message-id string
function event_id(h::EmailMessageEvent)
    return "email://" * h.id
end

# Simple status posting: insert a tiny rfc mail in Status folder, tag the original
function update_status!(h::EmailMessageEvent, text::AbstractString...)
    content = join(text, "\n")
    subj = "[status] " * (h.email === nothing ? h.id : h.email.headers.Subject)
    # Insert in Status folder; associate via In-Reply-To for threading
    try
        rfc = Notmuch.rfc_mail(
            subj, content;
            to = String[],  # internal status
            in_reply_to = h.id,
            keywords = ["status"],
        )
        notmuch_insert(rfc; folder="Status", tag=Notmuch.TagChange["+status/updated"])
        # Optionally tag the original
        notmuch_tag("id:$(h.id)" => Notmuch.TagChange("+", "status/updated"))
    catch e
        @warn "Failed to update email status" exception=(e, catch_backtrace())
    end
    nothing
end

# Final response: mirror status behavior
function send_final_response!(h::EmailMessageEvent, conv)
    # Append a final status; or transform conv into a summary mail
    try
        last = last(filter(PT.isaimessage, conv.conversation))
        content = last === nothing ? "Completed." : something(last.content, "Completed.")
        rfc = Notmuch.rfc_mail(
            "[complete] " * (h.email === nothing ? h.id : h.email.headers.Subject),
            content;
            to = String[],
            in_reply_to = h.id,
            keywords = ["status","done"],
        )
        notmuch_insert(rfc; folder="Status", tag=Notmuch.TagChange["+status/done"])
    catch
    end
end

end
