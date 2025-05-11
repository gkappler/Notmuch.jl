
using CombinedParsers
using CombinedParsers.Regexp

alpha = CharIn('a':'z','A':'Z')
alphanum = CharIn('a':'z','A':'Z','0':'9')
extrachar = CharIn("-+_.~")
word = !re"[^\v\h]+"
whitespace = re"[\v\h]+"
@with_names folder_parser =
    Either(Sequence(2,"\"",!re"[^\"]+","\"")
           ,Sequence(2,"'",!re"[^']+","'")
           ,!re"[^ ]+")
           

function Sentence(x...; at_start=Always(), whitespace = whitespace, at_end=Always())
    parts = CombinedParser[]
    push!(parts, parser(at_start))
    for (i,p_) in enumerate(x)
        p = parser(p_)
        if i == 1 
            push!(parts, p)
        elseif p isa Optional
            push!(parts, Sequence(2,Optional(whitespace), p))
        else
            push!(parts, Sequence(2,whitespace, p))
        end
    end
    push!(parts, parser(at_end))
    map(Sequence(parts...)) do v
        v[2:end-1]
    end
end
Base.getindex(x::typeof(Notmuch.Sentence), i::Int) =
    (a...;kw...) -> map(IndexAt(i),x(a...;kw...))
Base.getindex(x::Type{<:CombinedParsers.Sequence}, i::Int) =
    (a...;kw...) -> map(IndexAt(i),CombinedParsers.Sequence(a...;kw...))

msmtp_setting(x) =
    Sequence(3, x, whitespace, word, whitespace) do v
        Symbol(x) => v
    end

export parse_msmtp_cfg

parse_msmtp_cfg() =
    Sequence(
        msmtp_setting("account"),
        Repeat(
            Either(
                msmtp_setting.([
                    "host",
                    "from",
                    "domain", # ?
                    "port",
                    "tls",
                    "tls_starttls",
                    "tls_certcheck",
                    "tls_trust_file",
                    "auth", 
                    "user",
                    "password",
                    "logfile",
                    "#"
                ]
                               )))
    ) do v
        SMTPConfig(v[1].second; v[2]...)
    end

export Mailbox
struct Mailbox
    user::String
    domain::String
end
function Base.show(io::IO, x::Mailbox)
    printstyled(io, x.user; color = :yellow)
    printstyled(io, "@", x.domain; color = :brown)
end
## is this official??
NameMailbox = NamedTuple{(:name,:email), Tuple{String,Mailbox}}
function Base.show(io::IO, x::NameMailbox)
    x.name == "" || printstyled(io,x.name," "; color = :yellow)
    print(io,x.email)
end

email_regexp = Sequence(
    !re"[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+",
    "@",!re"[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*") do v
        Mailbox(v[1], v[3])
    end
#email_adress_parser = !re"[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*"

# author_email = Either(
#     Sequence(
#         :name => !Repeat(CharNotIn('<')),
#         CombinedParsers.horizontal_space_maybe,"<",
#         :email => email_regexp,
#         ">"),
#     map(email_regexp) do v
#         (name = "",
#          email =v)
#     end
# )

email_parser = Either(map(email_regexp) do v
                          (name = "", email =v)
                      end
                      , Sequence(re" *\"",:name => !re"[^\"]*",re"\" *<",:email => email_regexp,">")
                      , Sequence(re" *", :name => !re"[^\"]*",re" *<",:email => email_regexp,">")
                      , Sequence(re" *",!re"[^\"]*",re" +",email_regexp,re" *\( *",!re"[^\)]*",re" *",")") do v
                          (name = chomp(v[2] * " " * v[6]), email =v[4])
                      end)


notmuch_query_parser = begin
    crit(x) = map(Sequence(x,":", !re"[^ :]+")) do v
        NotmuchLeaf{Symbol(x)}(v[3])
    end
    @with_names atomic_term = Either(CombinedParser[crit(k) for k in ["from", "tag", "to", "id","thread","date","folder" ] ])
    @with_names leaf_term = Either(CombinedParser[
        map(Sequence(re" *not +", atomic_term)) do v
            NotmuchLeaf{:not}(v[2])
        end
        , atomic_term])
    
    ort = map(join(leaf_term, re" +or +")) do v
        or_query(v...)
    end
    term = map(join(ort, re" +and +")) do v
        and_query(v...)
    end
    pushfirst!(atomic_term, with_name(:parenthesis,Sequence(2,re" *\( *",term,re" *\) *")))
           
    Sequence(1,term,AtEnd())
end

move_rule_parser =
    Sentence[2]("mv",
                map(MailsRule,
                    Sentence(map(FolderChange,
                                 Sentence(folder_parser,
                                          folder_parser)),
                             Optional(integer_base(10); default=0),
                             notmuch_query_parser)))
tag_parser = join(map(TagChange,
                 Sequence(
                     Either("+", "-"),
                     !Repeat1(CharNotIn(" ")))),
                  whitespace
                  )

tag_rule_parser = 
    map(MailsRule,
        Either(
            Sentence(
                Sentence[1](
                    tag_parser
                    ,"tag")
                , Optional(integer_base(10), default=0),
                notmuch_query_parser)
            , Sequence[2](
                Either("Notmuch.MailTagChange(","Notmuch.RuleMail2("),
                Sequence(map(TagChange,!Sequence(Either("+", "-"),!Repeat1(CharNotIn(" ")))),
                         Sequence[3](", \"", !Repeat_until(AnyChar(), "\") tag "),
                                     integer_base(10), " "),
                         notmuch_query_parser))
        ));


rule_parser=Either(move_rule_parser, tag_rule_parser)

function splitter(key; delim=";")
    NamedParser(Symbol(key),Sequence(
        key, re" *= *",
        join(!Regcomb("[^$delim\n]+"),delim), "\n") do v
                (key = Symbol(key), value = strip.(v[3]))
                end
                )
end

function parse_cfg(keyvalues...)
    line = !Atomic(Sequence(1, !re"[^\n]+"))
    @with_names section = Atomic(Sequence(2,"[", !re"[^]]+", "]", whitespace))
    @with_names comment = Atomic(Sequence(2,re"#+ *", !re"[^\n]*"))
    whitespace_newline = !re" *\n"
    setting =
        Either(
            keyvalues...,
            Sequence(:key => !Atomic(re"[a-zA-Z0-9_]+"), re" *= *", :value => Atomic(line)),
            Either(
                comment,
                whitespace_newline) do v
                    nothing
                end
        )
    #
    ignored = Either(
        comment,
        whitespace_newline) do v
            nothing
        end
    Repeat(Either(
        Sequence(
            section,
            Repeat(Either(ignored,setting))) do v
                sect,set = v
                Symbol(sect) => Dict(
                    [ (Symbol(k.key) => k.value)
                      for k in set
                          if k !== nothing ]...
                              )
            end,
        ignored
    )) do v
        Dict{Symbol,Any}(filter(x -> x!==nothing, v)...)
    end
end

export parse_notmuch_config
parse_notmuch_cfg = 
    parse_cfg(
        splitter("tags"),
        splitter("exclude_tags"),
        splitter("primary_email"),
        splitter("other_email")
    )
