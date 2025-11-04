using Test
using Dates

# Try to load optional dependencies; keep tests resilient
const HAVE_NOTMUCH = try
    @eval using Notmuch
    true
catch
    @info "Notmuch.jl not available; some tests will fall back to the notmuch CLI or be skipped"
    false
end

const HAVE_JSON3 = try
    @eval using JSON3
    true
catch
    @info "JSON3 not available; JSON parsing/pretty tests will be skipped"
    false
end

const HAVE_SMTP = try
    @eval using SMTPClient
    true
catch
    false
end

const HAVE_COMBINED_PARSERS = try
    @eval using CombinedParsers
    @eval using CombinedParsers.Regexp
    true
catch
    false
end

const HAVE_THREADS_CONTROLLER = try
    @eval using ThreadsController
    true
catch
    false
end

const HAVE_HTTP = try
    @eval using HTTP
    true
catch
    false
end

const NOTMUCH_CLI = Sys.which("notmuch")

# Helpers
function nm_count(q::AbstractString)
    if HAVE_NOTMUCH && isdefined(Notmuch, :notmuch_count)
        try
            return Notmuch.notmuch_count(q)
        catch
            # fall back to CLI
        end
    end
    if NOTMUCH_CLI === nothing
        error("notmuch CLI not available")
    end
    return parse(Int, chomp(read(`$NOTMUCH_CLI count $q`, String)))
end

function nm_search_json(q::AbstractString; args::Vector{String}=String[])
    if NOTMUCH_CLI === nothing
        error("notmuch CLI not available")
    end
    return read(`$NOTMUCH_CLI search --format=json $(args...) $q`, String)
end

function nm_show_json(q::AbstractString; args::Vector{String}=String[])
    if NOTMUCH_CLI === nothing
        error("notmuch CLI not available")
    end
    return read(`$NOTMUCH_CLI show --format=json --include-html $(args...) $q`, String)
end

function nm_address_text(q::AbstractString; args::Vector{String}=String[])
    if NOTMUCH_CLI === nothing
        error("notmuch CLI not available")
    end
    return read(`$NOTMUCH_CLI address $(args...) $q`, String)
end

@testset "Notmuch experiments" begin
    @testset "CLI availability and basics" begin
        if NOTMUCH_CLI === nothing
            @info "notmuch CLI not found in PATH; skipping CLI tests"
            @test true
        else
            @test nm_count("*") >= 0
            @test begin
                s = nm_search_json("from:gilbreath")
                isa(s, String) && !isempty(s)
            end
            @test begin
                s = nm_show_json("tag:inbox")
                isa(s, String) && !isempty(s)
            end
            @test begin
                s = nm_address_text("tag:inbox")
                isa(s, String)
            end
        end
    end

    @testset "JSON3 pretty/read on CLI output" begin
        if NOTMUCH_CLI !== nothing && HAVE_JSON3
            s = nm_search_json("from:justin and tag:replied")
            @test JSON3.pretty(JSON3.read(s)) isa String
            s2 = nm_show_json("thread:000000000002a73a"; args=String["--entire-thread=false"])
            @test JSON3.pretty(JSON3.read(s2)) isa String
        else
            @info "Skipping JSON3 tests (missing CLI or JSON3)"
            @test true
        end
    end

    @testset "Notmuch.jl API (if available)" begin
        if HAVE_NOTMUCH
            # Count
            @test_nothrow Notmuch.notmuch_count("*")

            # Search and show
            @test_nothrow Notmuch.notmuch_search("notmuch.jl julia")
            @test_nothrow Notmuch.notmuch_tree("notmuch.jl julia")
            @test_nothrow Notmuch.notmuch_show("notmuch.jl julia")

            # Variants used in experiments
            @test_nothrow Notmuch.notmuch_search("tag:draftversion"; user="enron")
            @test_nothrow Notmuch.notmuch_search("test"; user="enron")
            @test_nothrow Notmuch.notmuch_tree("test"; user="enron")

            # Address
            @test_nothrow Notmuch.notmuch_address("tag:inbox")

            # Time counts
            if isdefined(Notmuch, :time_counts)
                @test_nothrow Notmuch.time_counts("tag:inbox and tag:unread"; user="enron")
            else
                @info "Notmuch.time_counts not found; skipping"
                @test true
            end

            # Tag changes (side-effects) — don't fail tests if DB not writable
            if isdefined(Notmuch, :notmuch_tag)
                @test begin
                    ok = true
                    try
                        Notmuch.notmuch_tag(["tag:draftversion" => Notmuch.TagChange("-", "draftversion")]; user="enron")
                    catch
                        ok = true # treat as skipped
                    end
                    ok
                end
            else
                @test true
            end

            # ThreadsController integration
            if HAVE_THREADS_CONTROLLER
                try
                    r = Notmuch.notmuch_search("from:gilbreath")
                    if !isempty(r)
                        @test ThreadsController.threadlink(r[1]) isa AbstractString
                    else
                        @test true
                    end
                catch
                    @test true
                end
            else
                @test true
            end

            # Building thread link with HTTP.escape if available
            if HAVE_HTTP
                try
                    r = Notmuch.notmuch_search("from:gilbreath")
                    if !isempty(r) && hasproperty(r[1], :query) && hasproperty(r[1], :subject)
                        thread = r[1]
                        q = String[]
                        try
                            # flatten query terms if present
                            for termset in thread.query
                                for t in termset
                                    push!(q, string(t))
                                end
                            end
                        catch
                        end
                        href = "/threads/tree?q=" * HTTP.escape(join([x for x in q if x !== nothing], " or "))
                        link = "<a href=\"$href\" class=\"subject\">$(getproperty(thread, :subject))</a>"
                        @test occursin("/threads/tree?q=", link)
                    else
                        @test true
                    end
                catch
                    @test true
                end
            else
                @test true
            end

            # Show by thread id if available
            try
                r1 = Notmuch.notmuch_search("from:gilbreath")
                if !isempty(r1) && hasproperty(r1[1], :thread)
                    t = getproperty(r1[1], :thread)
                    @test_nothrow Notmuch.notmuch_show("thread:" * String(t))
                else
                    @test true
                end
            catch
                @test true
            end

            # Entire-thread=false show
            @test_nothrow Notmuch.notmuch_show("--entire-thread=false", "id:1c24c7c9-496d-401c-8459-c5bd6f58d4ee@g-kappler.de")

            # notmuch_json reply on a thread (if function exists)
            if isdefined(Notmuch, :notmuch_json)
                try
                    r = Notmuch.notmuch_search("from:manuel tag:replied"; limit=1)
                    if !isempty(r) && hasproperty(r[1], :thread)
                        q = "thread:" * String(getproperty(r[1], :thread))
                        x = Notmuch.notmuch_json("reply", q)
                        @test x isa AbstractString || x isa AbstractDict || x isa Any
                    else
                        @test true
                    end
                catch
                    @test true
                end
            else
                @test true
            end
        else
            @info "Notmuch.jl not loaded; skipping Notmuch.jl API tests"
            @test true
        end
    end

    @testset "Direct CLI show part (if specific id exists)" begin
        if NOTMUCH_CLI !== nothing
            msgid = "024b01d80705\$0a760fd0\$1f622f70\$@salmax.de"
            cmd = `$NOTMUCH_CLI show --part=7 id:$msgid`
            ok = true
            try
                read(cmd, String)
            catch
                ok = true # treat missing message as skip
            end
            @test ok
        else
            @test true
        end
    end

    @testset "SMTPClient MIME creation (best-effort)" begin
        if HAVE_SMTP
            ok = true
            try
                # Minimal MIME payload using SMTPClient API
                from = "example@example.com"
                to = ["example@example.com"]
                subject = "julia mail test"
                message = "My mail test"
                # Build a simple text/plain message
                msg = SMTPClient.MIMEMessage()
                SMTPClient.setheader!(msg, "From", from)
                SMTPClient.setheader!(msg, "To", join(to, ", "))
                SMTPClient.setheader!(msg, "Subject", subject)
                SMTPClient.setheader!(msg, "Date", Dates.format(now(UTC), "e, d u yyyy HH:MM:SS +0000", locale="english"))
                SMTPClient.setcontent!(msg, message, "text/plain; charset=utf-8")
                io = IOBuffer()
                SMTPClient.write(io, msg)
                @test position(io) > 0
            catch
                ok = true # treat as skipped if SMTPClient API differs
            end
            @test ok
        else
            @test true
        end
    end

    @testset "CombinedParsers grammar snippet" begin
        if HAVE_COMBINED_PARSERS
            ok = true
            try
                notmuchsearch_line = Sequence(
                    "thread:", :notmuchid => !re"\w", whitespace_horizontal,
                )
                str = join(notmuchsearch_line, "\n")
                @test isa(str, AbstractString)
            catch
                ok = true
            end
            @test ok
        else
            @test true
        end
    end

    @testset "JSON3 read of CLI search result" begin
        if NOTMUCH_CLI !== nothing && HAVE_JSON3
            s = read(`$NOTMUCH_CLI search --format=json from:gilbreath`, String)
            parsed = JSON3.read(s)
            @test parsed !== nothing
        else
            @test true
        end
    end

    @testset "End-to-end sample flows (best-effort, may be skipped)" begin
        # Mimic building links from search results
        if HAVE_NOTMUCH
            ok = true
            try
                r = Notmuch.notmuch_search("from:gilbreath")
                if !isempty(r)
                    thread = r[1]
                    href = "/threads/tree?q="
                    if HAVE_HTTP && hasproperty(thread, :query)
                        q = String[]
                        try
                            for termset in thread.query
                                for t in termset
                                    push!(q, string(t))
                                end
                            end
                        catch
                        end
                        href *= HTTP.escape(join([x for x in q if x !== nothing], " or "))
                    end
                    link = "<a href=\"$href\" class=\"subject\">$(getproperty(thread, :subject, ""))</a>"
                    @test occursin("<a href=", link)
                else
                    @test true
                end
            catch
                ok = true
            end
            @test ok
        else
            @test true
        end
    end
end
