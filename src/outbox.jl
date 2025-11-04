# src/outbox.jl
module Outbox

using ..Notmuch
using ..Notmuch: Email, recipients_parser, notmuch_ids, notmuch_tag
using ..Notmuch: msmtp_config, primary_email
using SMTPClient

export SMTPSettings, smtp_settings_map, queue_mail, outbox_ids, send_outbox

# Per-account settings used to drive SMTPClient
Base.@kwdef struct SMTPSettings
    url::String            # e.g. "smtps://smtp.example.com:465" or "smtp://smtp.example.com:587"
    username::String = ""
    password::String = ""
    isSSL::Bool = true     # true for smtps and STARTTLS (curl's CURLOPT_USE_SSL)
    from::String           # sender address for this account (key for selection)
    verbose::Bool = false
end

# -- Helpers ------------------------------------------------------------------

_parse_bool(x) = lowercase(string(x)) in ("1","true","on","yes")
_parse_int(x) = try parse(Int, string(x)) catch; nothing end

# Map msmtp config into SMTPSettings
function _settings_from_msmtp(cfg)::Union{SMTPSettings,Nothing}
    host = cfg.host
    host == "" && return nothing
    port = _parse_int(cfg.port)
    tls = _parse_bool(cfg.tls)
    starttls = _parse_bool(cfg.tls_starttls)
    user = cfg.user
    pass = cfg.password
    from = cfg.from == "" ? "" : cfg.from

    # Decide URL + SSL
    url::String
    isSSL::Bool
    if tls && (port === nothing || port == 465)
        # implicit TLS
        url = "smtps://$host:$(something(port,465))"
        isSSL = true
    elseif starttls || (port !== nothing && port == 587)
        # STARTTLS over smtp
        url = "smtp://$host:$(something(port,587))"
        isSSL = true
    elseif tls
        # tls requested but port !=465: prefer smtps with provided port
        url = "smtps://$host:$(port === nothing ? 465 : port)"
        isSSL = true
    else
        # plain smtp (discouraged)
        url = "smtp://$host:$(something(port,25))"
        isSSL = false
    end

    return SMTPSettings(; url=url, username=user, password=pass, isSSL=isSSL,
                        from=from == "" ? primary_email() : from)
end

# Public: Build map from sender email -> SMTPSettings
function smtp_settings_map(; kw...)
    cfgs = msmtp_config(; kw...)  # Vector{SMTPConfig} or []
    mp = Dict{String,SMTPSettings}()
    for c in cfgs
        st = _settings_from_msmtp(c)
        st === nothing && continue
        mp[st.from] = st
    end
    mp
end

# Extract recipients from Email headers (To/Cc)
function _collect_recipients(e::Email)
    emails = String[]
    for field in (:To, :Cc)
        s = getproperty(e.headers, field)
        if !isempty(s)
            for t in Notmuch.recipients_parser(s; trace=false)
                push!(emails, string(t.email.user, "@", t.email.domain))
            end
        end
    end
    unique(emails)
end

# Determine From for selection
function _from_address(e::Email)
    f = getfield(e.headers, :From)
    parsed = Notmuch.tryparse(Notmuch.email_parser, f; trace=false)
    parsed === nothing && return ""
    return parsed.email.user * "@" * parsed.email.domain
end

# Queue helpers ---------------------------------------------------------------

# Typical Outbox queue: insert RFC and tag as queued
function queue_mail(rfc::AbstractString; folder="Outbox", tags=Notmuch.TagChange["+queued"], kw...)
    Notmuch.notmuch_insert(rfc; folder=folder, tag=tags, kw...)
    nothing
end

function queue_mail(; subject::AbstractString,
                    content::AbstractString,
                    to::Vector{<:AbstractString},
                    from::Union{Missing,String}=missing,
                    cc::Vector{<:AbstractString}=String[],
                    bcc::Vector{<:AbstractString}=String[],
                    keywords::Vector{String}=String[],
                    folder="Outbox",
                    tags=Notmuch.TagChange["+queued"],
                    kw...)
    rfc = Notmuch.rfc_mail(subject, content; from=from, to=to, cc=cc, bcc=bcc, keywords=keywords, kw...)
    queue_mail(rfc; folder=folder, tags=tags, kw...)
end

# Outbox query
outbox_ids(; q="folder:Outbox and tag:queued and not tag:sent and not tag:failed", limit=missing, kw...) =
    Notmuch.notmuch_ids(q; limit=limit, kw...)

# -- Sending ------------------------------------------------------------------

"""
    send_outbox(; settings_map=smtp_settings_map(), filter_sender=nothing,
                  limit=100, dryrun=false, move_to="Sent",
                  tag_no_config="failed/no_config", kw...)

Send queued Outbox messages via SMTP.

Modes:
- Single pass with per-message selection: `filter_sender === nothing` (default).
- Per-sender pass: set `filter_sender="<sender@example.com>"` to send only those.
Behavior:
- On success: tags `+sent -queued -new` and optionally moves Maildir Outbox/* → `move_to/*`.
- On no matching config: skip and optionally tag `+failed/no_config` when `tag_no_config != ""`.
- On SMTP failure: tag `+failed` (retains `queued` to retry); preserves file.
Returns: (sent=Vector{String}, failed=Vector{Pair{String,Exception}}, skipped=Vector{String})
"""
function send_outbox(; settings_map::Dict{String,SMTPSettings}=smtp_settings_map(),
                     filter_sender::Union{Nothing,String}=nothing,
                     limit::Int=100, dryrun::Bool=false,
                     move_to::Union{Nothing,String}="Sent",
                     tag_no_config::AbstractString="failed/no_config",
                     kw...)
    ids = outbox_ids(; limit=limit, kw...)
    isempty(ids) && return (sent=String[], failed=Pair{String,Exception}[], skipped=String[])

    sent = String[]; failed = Pair{String,Exception}[]; skipped = String[]

    # Pre-build SendOptions cache per settings object to avoid re-alloc
    opts_cache = Dict{String,SMTPClient.SendOptions}()

    for id in ids
        e = try
            Notmuch.Email(id; body=false, kw...)
        catch ex
            push!(failed, id => ex); continue
        end

        from_addr = _from_address(e)
        if isempty(from_addr)
            # no From → cannot route
            if tag_no_config != ""
                try Notmuch.notmuch_tag("id:$id" => Notmuch.TagChange("+", tag_no_config); kw...) catch end
            end
            push!(skipped, id)
            continue
        end

        # If per-sender run, filter
        if filter_sender !== nothing && from_addr != filter_sender
            push!(skipped, id)
            continue
        end

        st = get(settings_map, from_addr, nothing)
        if st === nothing
            # no matching account
            if tag_no_config != ""
                try Notmuch.notmuch_tag("id:$id" => Notmuch.TagChange("+", tag_no_config); kw...) catch end
            end
            push!(skipped, id)
            continue
        end

        recips = _collect_recipients(e)
        if isempty(recips)
            # nothing to send
            if tag_no_config != ""
                try Notmuch.notmuch_tag("id:$id" => Notmuch.TagChange("+", tag_no_config); kw...) catch end
            end
            push!(skipped, id)
            continue
        end

        # Read raw RFC
        if isempty(e.filename)
            push!(failed, id => ErrorException("No backing file")); continue
        end
        mailfile = e.filename[1]
        body = try read(mailfile, String) catch ex; push!(failed, id => ex); continue end

        # Lazily construct SendOptions per-URL (string key)
        key = st.url * "|" * st.username * "|" * string(st.isSSL)
        opts = get!(opts_cache, key) do
            SMTPClient.SendOptions(; isSSL=st.isSSL, username=st.username, passwd=st.password, verbose=st.verbose)
        end


        try
            # Mark sending (transient) for crash/retry visibility
            try Notmuch.notmuch_tag("id:$id" => Notmuch.TagChange("+", "sending"); kw...) catch end

            if !dryrun
                SMTPClient.send(st.url, recips, st.from, IOBuffer(body), opts)
            end

            # Success: mark sent + unqueue
            Notmuch.notmuch_tag("id:$id" => Notmuch.TagChange("+", "sent"); kw...)
            Notmuch.notmuch_tag("id:$id" => Notmuch.TagChange("-", "queued"); kw...)
            Notmuch.notmuch_tag("id:$id" => Notmuch.TagChange("-", "new"); kw...)
            Notmuch.notmuch_tag("id:$id" => Notmuch.TagChange("-", "sending"); kw...)  # clear transient
           
            # Optional physical move
            if move_to !== nothing
                # Move Outbox -> Sent preserving cur/new/tmp; leverage FolderChange rule
                Notmuch.apply_rule(
                    Notmuch.MailsRule(Notmuch.FolderChange("Outbox", move_to),
                                      1,
                                      Notmuch.query_parser("id:$id"; trace=false));
                    kw...)
            end

            push!(sent, id)
        catch ex
            # Failure: keep queued, mark failed; clear transient
            try Notmuch.notmuch_tag("id:$id" => Notmuch.TagChange("+", "failed"); kw...) catch end
            try Notmuch.notmuch_tag("id:$id" => Notmuch.TagChange("-", "sending"); kw...) catch end
            push!(failed, id => ex)
        end
    end

    (sent=sent, failed=failed, skipped=skipped)
end

end # module
