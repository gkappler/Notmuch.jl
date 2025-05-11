using Parameters;
    
tags = (IMAP = [ "unread", "new", "flagged","attachment" ]
        , reply = [ "reply", "replied" ]
        , folders = [ "inbox","draft","draftversion", "sent" ]
        , elmail = [ "expanded","todo","done"]
        )

usertags(x) =
    [ tag for tag in x
         if !(tag in vcat(tags...))]



"""
    TagChange(prefixtag::AbstractString)
    TagChange(prefix::AbstractString, tag::AbstractString)

Prefix is either "+" for adding or "-" for removing a tag.
"""
@auto_hash_equals struct TagChange
    prefix::String
    tag::String
    function TagChange(prefix, tag)
        @assert prefix in ["+","-"]
        new(prefix,tag)
    end
end
query(x::AbstractString) = query_parser(x; trace=true)
function query(x::TagChange)
    if x.prefix == "+"
        NotmuchLeaf{:not}(NotmuchLeaf{:tag}(x.tag))
    else
        NotmuchLeaf{:tag}(x.tag)
    end
end

function TagChange(tag)
    tag_parser(tag)
end

export @tag_str
macro tag_str(x)
    quote
        TagChange($x)
    end
end

Base.isequal(x::TagChange, y::TagChange) =
    x.tag == y.tag && x.prefix == y.prefix

Base.isless(x::TagChange, y::TagChange) =
    isless(x.prefix, y.prefix) || (isequal(x.prefix, y.prefix)  && isless(x.tag, y.tag))

function StyledStrings.annotatedstring(x::TagChange)
    removed = x.prefix == "-"
    str = if removed
        styled"{:{bright_red:$(x.prefix)}}{strikethrough:{cyan:$(x.tag)}}"
    else
        styled"{bold:{green:$(x.prefix)}}{cyan:$(x.tag)}"
    end
end

Base.show(io::IO,x::TagChange) =
    print(io, annotatedstring(x))

export notmuch_tag



"""
    notmuch_tag(batch::Pair{<:AbstractString,<:AbstractString}...; kw...)
    notmuch_tag(batch::Vector{Pair{String,TagChange}}; kw...)

Tag `query => tagchange` entries in `batch` mode.

Spaces in tags are supported, but other query string encodings for [`notmuch tag`](https://manpages.ubuntu.com/manpages//bionic/man1/notmuch-tag.1.html) are currently not.

For user `kw...` see [`userENV`](@ref).
"""
function notmuch_tag(batch::Dict;kw...)
    open(
        Notmuch.notmuch_cmd("tag", "--batch"; kw...),
        "w", stdout) do io
            for (q, tagchanges) in batch
                # @info "tag $q" tagchanges
                print_tags(io,tagchanges)
                println(io, " -- ", q)
                print_tags(stdout,tagchanges)
                println(" -- ", q)
            end
        end
end 

print_tags(io, tags::String) =
    print_tags(io, TagChange(tags))

print_tags(io, tags::TagChange) =
    print(io, tags.prefix, replace(tags.tag, " " => "%20"))
print_tags(io, tags::AbstractVector) =
    join(io, tags, " ")

notmuch_tag(batch::Pair...; kw...) =
    notmuch_tag(Dict(batch...); kw...)
notmuch_tag_from(batch::Pair{<:AbstractString,<:AbstractString}...; kw...) =
    notmuch_tag(Dict("from:$f" => [TagChange(t) for t in split(x," ")]
                     for (f,x) in batch); kw...)
    
