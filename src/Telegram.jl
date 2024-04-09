module Telegram
using JSON3
using Dates
using SMTPClient
telegram_id(x::Int) =
    "user$x@telegram_elmail"
telegram_id(x::AbstractString) =
    x*"@telegram_elmail"
telegram_id(x::Nothing) =
    ""
telegram_mail(x::String) =
    "$x.telegram@elmail.g-kappler.de"
telegram_mail(x::Int) =
    "user$x.telegram@elmail.g-kappler.de"
telegram_mail(m::JSON3.Object) =
    replace(m[:from], r"[^\w]+" => " ")*" <" * telegram_mail(m[:from_id]) * ">"

lines(x::AbstractString) =
    split(x,"\n")
lines(x::AbstractArray) =
    vcat(lines.(x)...)
function lines(x::JSON3.Object)
    if x[:type] == "link"
        x[:text]
    elseif x[:type] == "text_link"
        "[$(x[:text])]($(x[:href]))"
    elseif x[:type] == "mention"
        "$(x[:text])"
    elseif x[:type] == "mention_name"
        "[$(x[:text])](mailto:$(telegram_mail(x[:user_id])))"
    elseif x[:type] == "bold"
        "**$(x[:text])**"
    elseif x[:type] == "phone"
        "☎ $(x[:text])"
    elseif x[:type] == "hashtag"
        "$(x[:text])"
    elseif x[:type] == "italic"
        "*$(x[:text])*"
    else
        print(x)
        error()
        x[:text]
    end
end


using JSON3


function importChatExport(filename;  to,  email = telegram_mail)
    ms = JSON3.read(read(filename,String))
    for m in ms[:messages]
        rfc = if m[:type] == "service"
            rfc_mail(from=m[:actor]*" <"*telegram_mail(m[:actor_id])*">",
                     to = to,
                     date = unix2datetime(parse(Int,m[:date_unixtime])),
                     subject =  m[:action],
                     content = SMTPClient.Plain(""),
                     messageid = telegram_id(m[:id]),
                     keywords = ["telegram", m[:action]])
        elseif m[:type] == "message"
            ls = lines(m[:text])
            rfc_mail(from=get(m,:forwarded_from,email(m)),
                     to = to,
                     date = unix2datetime(
                         parse(Int,
                               get!(m,:edited_unixtime) do
                                   m[:date_unixtime]
                               end)),
                     # "edited": "2020-11-10T19:18:38",
                     # "edited_unixtime": "1605032318",
                     messageid = telegram_id(m[:id]),
                     inreplyto = telegram_id(get(m, :reply_to_message_id, nothing)),
                     subject =  ls[1],
                     content = SMTPClient.Plain(join(ls[2:end],"\n")),
                     keywords = ["telegram"])
        else
            error(m)
        end
        print(rfc)
        notmuch_insert(rfc
                       ; tags = [ TagChange("+", t) for t in ["telegram"] ]
                       , folder="telegram-test"
                       )
    end
end

function blogpost(; date = Dates.now(), content, keywords, kw...)
    date = Dates.format(date, "yyyy-mm-dd HH:MM")
    keywords = join(keywords, " ")
    """
    ---
    date: $date
    tags: $keywords
    """ * join([ "$k: $v" for (k,v) in kw ], "\n") * "\n" *
    """
    ---
    $content
    """ 
end

function blogChatExport(filename;  email = telegram_mail)
    ms = JSON3.read(read(filename,String))
    for m in ms[:messages]
        println(m)
        readline()
        rfc = if m[:type] == "service"
            blogpost(from=m[:actor]*" <"*telegram_mail(m[:actor_id])*">",
                     date = unix2datetime(parse(Int,m[:date_unixtime])),
                     title =  m[:action],
                     content = "",
                     messageid = telegram_id(m[:id]),
                     keywords = ["telegram", m[:action]])
        elseif m[:type] == "message"
            ls = lines(m[:text])
            blogpost(author=get(m,:forwarded_from,email(m)),
                     date = unix2datetime(
                         parse(Int,
                               get(m,:edited_unixtime) do
                                   m[:date_unixtime]
                               end)),
                     # "edited": "2020-11-10T19:18:38",
                     # "edited_unixtime": "1605032318",
                     messageid = telegram_id(m[:id]),
                     inreplyto = telegram_id(get(m, :reply_to_message_id, nothing)),
                     title =  ls[1],
                     content = (join(ls[2:end],"\n")),
                     keywords = ["telegram"])
        else
            error(m)
        end
        print(rfc)
        # notmuch_insert(rfc
        #                ; tags = [ TagChange("+", t) for t in ["telegram"] ]
        #                , folder="telegram-test"
        #                )
    end
end

end
