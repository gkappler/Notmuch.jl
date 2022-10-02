Genie.Generator.write_secrets_file()

using Notmuch
using JSON3
ENV["NOTMUCHJL"] = "/home/gregor/dev/julia/Notmuch"
ENV["NOMAILDIR"] = "/home/gregor"
ENV["NOHOME"] = "/home/gregor"

ENV["JULIA_DEBUG"] = "jskdhfkj"
notmuch_count("*")

notmuch_tree(Emails, "notmuch.jl julia")
notmuch_show(Emails, "notmuch.jl julia")

tc = Notmuch.time_counts("tag:inbox and tag:unread"; user="enron" )

notmuch_search(Thread,"tag:inbox","--sort=oldest-first", limit=1)
notmuch_address("tag:inbox")

JSON3.pretty(notmuch_search("from:justin and tag:replied"))
JSON3.pretty(notmuch_tree("from:justin and thread:000000000002a73a"))

notmuch_tree(Emails, "((tag:inbox)) and ((tag:unread)) and ((not (((tag:mlist)))))")

notmuch_search(Thread, "notmuch.jl julia")
notmuch_tree(Emails,"notmuch.jl julia")
notmuch_show(Emails,"notmuch.jl julia")

notmuch_search(Thread, "tag:draftversion", user = "enron")
notmuch_tag([ "tag:draftversion" => TagChange("-", "draftversion")],
            user = "enron")

notmuch_search(Thread, "test", user = "enron")
notmuch_tree(Emails, "test", user = "enron")




Notmuch.msmtp_runqueue!(user = "handelsregister")

Genie.Renderer.Html.details
/usr/bin/notmuch show --part=7 'id:024b01d80705$0a760fd0$1f622f70$@salmax.de'
using SMTPClient

from = "mail@g-kappler.de"
to = [ "mail@g-kappler.de" ]
message = "My mail test"
subject = "julia mail test"
attachments = String[] #"julia_logo_color.svg"]

mime_msg = get_mime_msg(message)

i = get_body(to, from, subject, mime_msg; attachments)
write_body(stdout,to, from, subject, mime_msg; attachments);

c = Notmuch.notmuch_cmd("insert", "--folder=juliatest", "--create-folder", "+draft")
read(run(pipeline(c; stdin = i)), String)
notmuch_search("julia mail test") |> first

notmuch_show("thread:"*notmuch_search("from:manuel tag:replied",limit=1)[1].thread)

notmuch_show("--entire-thread=false",
             "id:1c24c7c9-496d-401c-8459-c5bd6f58d4ee@g-kappler.de")



Notmuch.notmuch_json("reply", ("thread:"*notmuch_search("from:manuel tag:replied",limit=1)[1].thread)) |> println

write(stdout, i);
String(take!(i)) |> println


function print_mail(io::IO, x
    mail_recipient, mail_orders=[];
    msmtp_sender = env_msmtp_sender(),
    mail_name = env_msmtp_name(),
    # mail_name = "Handelsregisterauszüge online",
    mail_dir,
    mail_file = Dates.format(now(),"yyyy-mm-dd-HH.MM.SS")
    )
    dt, tz = Dates.format(now(), DateFormat("e, d u Y H:M:S")), get(ENV, "TIMEZONE", "+0100")
    ascii = show(io,MIME("text/ascii"), x)
    html = show(io,MIME("text/html"), x)

    message_id = "" # "Message-ID: <>"
    boundary = "=-=-="
    open(joinpath(mail_dir, "$mail_file.mail"), "w") do io
        println(io,
                """
    From: $mail_name <$msmtp_sender>
    To: $mail_recipient
    Subject: $subject
    Bcc: $mail_name <$msmtp_sender>
    Date: $dt $tz
    $(message_id)MIME-Version: 1.0
    Content-Type: multipart/alternative; boundary="$boundary"

    --boundary
    Content-Type: text/plain; charset=utf-8
    Content-Transfer-Encoding: quoted-printable

    Sehr geehrte*r $mail_recipient,

    Vielen Dank f=C3=BCr Ihre Bestellung:

    $docs_ascii

    Die bestellten Dokumente als PDF werden ihnen in K=C3=BCrze als Antwort an =
    diese email Adresse versandt: $mail_recipient

    Benötigen Sie eine Rechnung mit ausgewiesener Umsatzsteuer, dann schreiben Sie uns bitte Ihre Rechnungsadresse und als Antwort auf diese Email.

    Beste W=C3=BCnsche und Gr=C3=BC=C3=9Fe,
    Handelsregisterausz=C3=BCge online

    --boundary
    Content-Type: text/html; charset=utf-8
    Content-Transfer-Encoding: quoted-printable

    <p>
    Sehr geehrte*r $mail_recipient,
    </p>

    <p>
    Vielen Dank f=C3=BCr Ihre Bestellung:

    $docs_html

        Die bestellten Dokumente als PDF werden ihnen in K=C3=BCrze als Antwort an =
    diese email Adresse versandt: <b>$mail_recipient</b>
    </p>

    <p>
    Benötigen Sie eine Rechnung mit ausgewiesener Umsatzsteuer, dann schreiben Sie uns bitte Ihre Rechnungsadresse und als Antwort auf diese Email.
    </p>

    <p>
    Beste W=C3=BCnsche und Gr=C3=BC=C3=9Fe,
    Handelsregisterausz=C3=BCge online
    </p>

    --boundary--

        """
                )
    end


    function writebody(io::IO,
        to::Vector{String},
        from::String,
        subject::String,
        msg::String;
        cc::Vector{String} = String[],
        replyto::String = "",
        attachments::Vector{String} = String[]
        boundary = "Julia_SMTPClient-" * join(rand(collect(vcat('0':'9','A':'Z','a':'z')), 40))
        )

        

        tz = mapreduce(
            x -> string(x, pad=2), *,
            divrem( div( ( now() - now(Dates.UTC) ).value, 60000, RoundNearest ), 60 )
        )
        date = join([Dates.format(now(), "e, d u yyyy HH:MM:SS", locale="english"), tz], " ")

        print(io, "From: $from\r\n")
        print(io, "Date: $date\r\n")
        print(io, "Subject: $subject\r\n")
        if length(cc) > 0
            print(io, "Cc: $(join(cc, ", "))\r\n")
        end
        if length(replyto) > 0
            print(io, "Reply-To: $replyto\r\n")
        end
        print(io, "To: $(join(to, ", "))\r\n")

        if length(attachments) == 0
            print(io, "MIME-Version: 1.0\r\n",
                  "$msg\r\n\r\n")
        else
            print(io, 
                  "Content-Type: multipart/mixed; boundary=\"$boundary\"\r\n\r\n",
                  "MIME-Version: 1.0\r\n",
                  "\r\n",
                  "This is a message with multiple parts in MIME format.\r\n",
                  "--$boundary\r\n",
                  "$msg\r\n",
                  "--$boundary\r\n",
                  "\r\n",
                  end
                join(encode_attachment.(attachments, boundary), "\r\n")
        end
        body = IOBuffer(contents)
        return body
    end
end
    









using Notmuch
using Test

@testset "Notmuch.jl" begin
    # Write your tests here.
end

using CombinedParsers
using CombinedParsers.Regexp

using ThreadsController
s = read(`notmuch search --format=json from:gilbreath`, String)
ThreadsController.threadlink(notmuch_search("from:gilbreath")[1])
thread = notmuch_search("from:gilbreath")[1]
let href="/threads/tree?q=" * join(vcat(thread.query...),"%20or%20")
    "<a href=\"$href\" class=\"subject\">$(thread.subject)</a>"
end


  let href="/threads/tree?q=" * HTTP.escape(join(vcat([ l for l in thread.query if l!==nothing]...)," or "))
      "<a href=\"$href\" class=\"subject\">$(thread.subject)</a>"
  end

r1 = notmuch_search("from:gilbreath")|>first
notmuch_show("thread:"*r1.thread)
(;notmuch_show(string(r1.query[1][1]))[1]...)
notmuch_show(string(r1.query[1][1]))[1]

notmuch_tree("tags:new")


using JSON3
JSON3.read(s)

notmuchsearch_line = Sequence(
    "thread:", :notmuchid => !re"\w", whitespace_horizontal, 
)
join(notmuchsearch_line,"\n")
(s)

module Notmuch
using Dates
using JSON3
import Base: show
struct NotmuchID{type}
    id::String
end
function NotmuchID(x::AbstractString)
    type,id = split(x,":")
    NotmuchID{Symbol(type)}(id)
end
Base.show(io::IO, x::NotmuchID{t}) where t =
    print(io,t,":",x.id)

export SearchResult
# Write your package code here.
struct SearchResult
    thread::String
    date::DateTime
    matched::Int
    total::Int
    authors::String
    subject::String
    query::Vector{Vector{NotmuchID}}
    tags::Vector{Symbol}
end

Base.show(io::IO, x::SearchResult) where t =
    print(io,"$(x.date) $(x.authors)\n     ", x.subject)

function SearchResult(x::JSON3.Object)
    SearchResult(x.thread, unix2datetime(x.timestamp),
                 x.matched, x.total, x.authors, x.subject,
                 [ [ NotmuchID(id) for id in split(t," ") ]
                   for t in x.query
                       if t !== nothing],
                 [ Symbol(t) for t in x.tags ]
                 )
end

struct NotmuchMail
    json::JSON3.Object
end

Base.getproperty(x::NotmuchMail, y) =
    getfield(x,1)["$y"]

function BodyPart(x::JSON3.Object)
    (id = x.id, content_type = x["content-type"],
     content=x.content, content_charset = get(x, "content-charset", "UTF-8"),
     content_transfer_encoding = get(x, "content-charset", ""),
     # content_length = x["content-length"]
     )
end

export NotmuchMail
NotmuchMail(x::JSON3.AbstractVector) =
    map(NotmuchMail,x)

export notmuch_search
notmuch_search(x) =
    map(SearchResult, JSON3.read(read(`notmuch search --format=json $x`)))


export notmuch_show
notmuch_show(x) =
    JSON3.read(read(`notmuch show --format=json --include-html $x`))



using Genie
"""
HTML for a message.
```
.message > .title {}
.header
.email {}
.from {}
.to {}
.cc {}
.new .title { font-weight: bold; }
.body
```
"""
function Base.show(io::IO, ::MIME"text/html", x::NotmuchMail)
    Genie.p()
end

function NotmuchMail(x::JSON3.Object)
    (id = x.id,
     headers = Dict(x.headers),
     match = x.match,
     excluded = x.excluded,
     filename = x.filename,
     time = unix2datetime(x.timestamp),
     tags = [ Symbol(t) for t in x.tags ],
     body = collect(map(BodyPart, x.body))
     )
end


"""
HTML for a thread. 

Handle formatting and indentation in CSS:
```
.thread {
margin-left: 10em;
}
```
"""



end
