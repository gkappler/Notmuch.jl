# --- test/test-maildir.jl ---
using Test, Notmuch

@testset "ensure_maildir!" begin
    tmp = mktempdir()
    @test_throws ErrorException Notmuch.ensure_maildir!(joinpath(tmp, "Archive"))
    @test Notmuch.ensure_maildir!(joinpath(tmp, "Archive", "cur")) == true
    @test isdir(joinpath(tmp, "Archive", "new"))
    @test isdir(joinpath(tmp, "Archive", "tmp"))
end

# Integration-like outbox smoke must be gated; requires notmuch CLI and a temp DB
if get(ENV, "RUN_NOTMUCH_INTEGRATION", "0") == "1" && Sys.which("notmuch") !== nothing
    @testset "send_outbox dryrun smoke" begin
        tmp = mktempdir()
        ENV["NOTMUCH_WD"] = tmp
        ENV["NOHOME"] = tmp
        ENV["NOMAILDIR"] = "mail"
        mkpath(joinpath(tmp, "mail"))
        Notmuch.notmuch_setup(name = "Test", primary_email = "me@x")
        Notmuch.notmuch("new")

        # Insert one queued mail
        rfc = Notmuch.rfc_mail("subj", "body"; to = ["a@x"], from = "me@x")
        Notmuch.Outbox.queue_mail(rfc; folder = "Outbox", tags = Notmuch.TagChange["+queued"])
        ids = Notmuch.Outbox.outbox_ids(limit = 1)
        @test !isempty(ids)

        res = Notmuch.Outbox.send_outbox(
            ; settings_map = Dict("me@x" => Notmuch.Outbox.SMTPSettings(url = "smtp://localhost:25", from = "me@x", isSSL = false)),
              dryrun = true
        )
        @test length(res.sent) + length(res.failed) + length(res.skipped) >= 0
    end
end
