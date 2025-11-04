# test/test-query.jl
using Test, Notmuch

@testset "escape_id" begin
    @test Notmuch.escape_id("x@y") == "<x@y>"
    @test Notmuch.escape_id("<x@y>") == "<x@y>"
end

@testset "render Query" begin
    q = Notmuch.and_query(Notmuch.NotmuchLeaf{:from}("a@x"), Notmuch.NotmuchLeaf{:tag}("inbox"))
    @test Notmuch.render(q) == "(from:a@x and tag:inbox)"
    @test Notmuch.render(Notmuch.or_query(Notmuch.NotmuchLeaf{:from}("a@x"), Notmuch.NotmuchLeaf{:to}("a@x"))) ==
          "(from:a@x or to:a@x)"  # will usually be fromto normalized if you choose to render that way
end

# test/test-show-headers.jl
using Test, Notmuch, Dates
@testset "Header Date parse" begin
    s1 = "Sat, 28 May 2022 10:03:20 +0100"
    s2 = "Sat, 28 May 2022 10:03:20"
    d1 = Notmuch.headerfield(Val(:Date), s1)
    d2 = Notmuch.headerfield(Val(:Date), s2)
    @test d1 isa DateTime
    @test d2 isa DateTime
end

# test/test-outbox.jl
using Test, Notmuch
@testset "Recipients parse" begin
    # Fake Headers
    h = Notmuch.Headers((Subject="", From="", To="A <a@x>, b@x", Cc="C <c@x>", Date=now()))
    e = Notmuch.Email("dummy", true, false, String[], now(), "", String[], Content[], String[], h)
    rec = Notmuch.Outbox._collect_recipients(e)
    @test Set(rec) == Set(["a@x","b@x","c@x"])
end
@testset "Query normalize" begin
    f = Notmuch.NotmuchLeaf{:from}("a@x")
    t = Notmuch.NotmuchLeaf{:to}("a@x")
    q = Notmuch.or_query(f, t, f) # dup
    qn = Notmuch.normalize(q)
    @test Notmuch.render(qn) == "((from:a@x or to:a@x) or (fromto:a@x))" || Notmuch.render(qn) == "(fromto:a@x)"
    # From+To normalized to fromto; duplicates dropped
    @test occursin("fromto:a@x", Notmuch.render(qn))
end
