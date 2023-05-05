"""
`Notmuch.jl` opens maildir email data up for analyses in Julia by
providing a julia `Cmd` wrapper for [notmuch mail](https://notmuchmail.org/) database supporting arbitrary tags and advanced search.

Notmuch mail indexes emails into a xapian database from a maildir store.

maildir 
- is an standard for email datasets.
- can be smoothly synchronized with an IMAP server by [offlineimap](http://www.offlineimap.org/).

Genie routes are provided exposing notmuch search as an HTTP API.
"""
module Notmuch

using JSON3

using Logging, LoggingExtras

"""
    Key = Union{AbstractString,Symbol} 

Genie GET and POST key type.
"""
Key = Union{AbstractString,Symbol}

function main()
  Core.eval(Main, :(const UserApp = $(@__MODULE__)))

  Genie.genie(; context = @__MODULE__)

  Core.eval(Main, :(const Genie = UserApp.Genie))
  Core.eval(Main, :(using Genie))
end

include("genie.jl")

include("user.jl")

export notmuch_json, notmuch_search, notmuch_tree, notmuch_count, notmuch_cmd

"""
    notmuch_cmd(command, x...; log=false, kw...)

Build notmuch `command` with arguments `x...`.

For user `kw...` see [`userENV`](@ref).

Used in [`notmuch_json`](@ref) and  [`notmuch`](@ref).
"""
function notmuch_cmd(command, x...; log=false, kw...)
    env = userENV(; kw...)
    cfg = ".notmuch-config"
    y = [x...]
    c = Cmd(`/usr/bin/notmuch --config=$cfg $command $y`,
            env=env,
            dir=env["HOME"])
    log && @info "notmuch cmd" c
    c
end

"""
    notmuch(x...; kw...)

Run [`notmuch_cmd`](@ref) and return output as `String`.

See [`notmuch_json`](@ref)
To get json as a String, provide `"--format=json"` as argument.

For user `kw...` see [`userENV`](@ref).
"""
function notmuch(x...; kw...)
    r = try
        read(notmuch_cmd(x...; kw...), String)
    catch e
        @error "notmuch error" e
    end
    r
end


"""
    notmuch_json(command,x...; kw...)

Parse [`notmuch`](@ref) with `JSON3.read`.

For user `kw...` see [`userENV`](@ref).
"""
function notmuch_json(command,x...; kw...) 
    r = notmuch(command, "--format=json", x...; kw...)
    r === nothing && return nothing
    JSON3.read(r)
end

"""
    notmuch_count(x...; kw...)

from the man-page:

count messages matching the given search terms

       The number of matching messages (or threads) is output to stdout.

       With no search terms, a count of all messages (or threads) in the data‐
       base will be displayed.

       See notmuch-search-terms(7) for details of  the  supported  syntax  for
       <search-terms>.

       Supported options for count include

       --output=(messages|threads|files)

              messages
                     Output  the  number of matching messages. This is the de‐
                     fault.

              threads
                     Output the number of matching threads.

              files  Output the number of files associated with matching  mes‐
                     sages.  This  may  be  bigger than the number of matching
                     messages due to duplicates (i.e.  multiple  files  having
                     the same message-id).

       --exclude=(true|false)
              Specify  whether  to  omit messages matching search.exclude_tags
              from the count (the default) or not.

       --batch
              Read queries from a file (stdin by default), one per  line,  and
              output  the  number of matching messages (or threads) to stdout,
              one per line. On an empty input line the count of  all  messages
              (or  threads) in the database will be output. This option is not
              compatible with specifying search terms on the command line.

       --lastmod
              Append lastmod (counter for number of database updates) and UUID
              to  the output. lastmod values are only comparable between data‐
              bases with the same UUID.

       --input=<filename>
              Read input from given  file,  instead  of  from  stdin.  Implies
              --batch.
"""
function notmuch_count(x...; kw...)
    c = notmuch("count", x...; kw...)
    c === nothing && return nothing
    parse(Int,chomp(c))
end

include("Threads.jl")

ToF = Union{Type,Function}
LIMIT = 5
"""
    notmuch_search(query, x...; offset=0, limit=LIMIT, kw...)
    notmuch_search(T::Union{Type,Function}, x...; kw...)

Search notmuch and return threads json `Vector`.

With first argument `f::Union{Type,Function}` each result is converted with calling `f`, otherwise JSON is returned.

For user `kw...` see [`userENV`](@ref).

From the man page:

       Search for messages matching the given search terms, and display as
       results the threads containing the matched messages.

       The output consists of one line per thread, giving a thread ID, the
       date of the newest  (or  oldest,  depending  on  the  sort  option)
       matched  message  in the thread, the number of matched messages and
       total messages in the thread, the names of all participants in  the
       thread, and the subject of the newest (or oldest) message.

       See notmuch-search-terms(7) for details of the supported syntax for
       <search-terms>.

       Supported options for search include

       --format=(json|sexp|text|text0)
              Presents the results in either JSON, S-Expressions,  newline
              character  separated plain-text (default), or null character
              separated plain-text (compatible  with  xargs(1)  -0  option
              where available).

       --format-version=N
              Use  the specified structured output format version. This is
              intended for programs that invoke notmuch(1) internally.  If
              omitted, the latest supported version will be used.

       --output=(summary|threads|messages|files|tags)

              summary
                     Output  a  summary  of  each  thread with any message
                     matching the search terms. The summary  includes  the
                     thread ID, date, the number of messages in the thread
                     (both the number matched and the total  number),  the
                     authors  of  the  thread and the subject. In the case
                     where a thread contains multiple files for some  mes‐
                     sages, the total number of files is printed in paren‐
                     theses (see below for an example).

              threads
                     Output the thread IDs of all threads with any message
                     matching  the  search  terms,  either  one  per  line
                     (--format=text), separated by null characters (--for‐
                     mat=text0),  as  a  JSON array (--format=json), or an
                     S-Expression list (--format=sexp).

              messages
                     Output the message IDs of all messages  matching  the
                     search  terms,  either  one per line (--format=text),
                     separated by null characters (--format=text0),  as  a
                     JSON  array  (--format=json),  or  as an S-Expression
                     list (--format=sexp).

              files  Output the filenames of  all  messages  matching  the
                     search  terms,  either  one per line (--format=text),
                     separated by null characters (--format=text0),  as  a
                     JSON  array  (--format=json),  or  as an S-Expression
                     list (--format=sexp).

                     Note that each message may  have  multiple  filenames
                     associated  with  it. All of them are included in the
                     output (unless limited  with  the  --duplicate=N  op‐
                     tion). This may be particularly confusing for folder:
                     or path: searches in a specified  directory,  as  the
                     messages  may  have  duplicates  in other directories
                     that are included in the output, although these files
                     alone would not match the search.

              tags   Output  all  tags that appear on any message matching
                     the  search  terms,  either  one  per  line   (--for‐
                     mat=text),   separated  by  null  characters  (--for‐
                     mat=text0), as a JSON array (--format=json), or as an
                     S-Expression list (--format=sexp).

       --sort=(newest-first|oldest-first)
              This option can be used to present results in either chrono‐
              logical order (oldest-first) or reverse chronological  order
              (newest-first).

              Note:  The  thread  order will be distinct between these two
              options (beyond being simply reversed). When sorting by old‐
              est-first  the  threads will be sorted by the oldest message
              in each thread, but when sorting by newest-first the threads
              will be sorted by the newest message in each thread.

              By default, results will be displayed in reverse chronologi‐
              cal order, (that is, the newest results  will  be  displayed
              first).

       --offset=[-]N
              Skip  displaying  the first N results. With the leading '-',
              start at the Nth result from the end.

       --limit=N
              Limit the number of displayed results to N.

       --exclude=(true|false|all|flag)
              A message is called "excluded" if it matches  at  least  one
              tag  in  search.exclude_tags that does not appear explicitly
              in the search terms. This option specifies whether  to  omit
              excluded messages in the search process.

              true (default)
                     Prevent  excluded  messages  from matching the search
                     terms.

              all    Additionally prevent excluded messages from appearing
                     in  displayed  results,  in effect behaving as though
                     the excluded messages do not exist.

              false  Allow excluded messages to match search terms and ap‐
                     pear  in  displayed  results.  Excluded  messages are
                     still marked in the relevant outputs.

              flag   Only has an effect when --output=summary. The  output
                     is  almost  identical to false, but the "match count"
                     is the number of matching  non-excluded  messages  in
                     the  thread,  rather than the number of matching mes‐
                     sages.

       --duplicate=N
              For --output=files, output the Nth filename associated  with
              each  message  matching  the  query  (N is 1-based). If N is
              greater than the number of files associated  with  the  mes‐
              sage, don't print anything.

              For  --output=messages,  only output message IDs of messages
              matching the search terms that have at least N filenames as‐
              sociated with them.

              Note  that this option is orthogonal with the folder: search
              prefix. The prefix matches messages based on filenames. This
              option filters filenames of the matching messages.

"""
notmuch_search(query, x...; offset=0, limit=5, kw...) =
    notmuch_json(:search, "--offset=$offset", "--limit=$limit", x..., query; kw...)
notmuch_search(T::ToF, x...; kw...) =
    T.(notmuch_search(x...; kw...))
export notmuch_search

function counts(basq, a...; subqueries=String[], kw...)
    if isempty(subqueries)
        [ notmuch_count(a..., basq;kw...) ]
    else
        [ parse(Int,chomp(Notmuch.notmuch(
            "count", basq !== nothing ? "($basq) and ($t)" : t;
            kw...)))
          for t in subqueries ]
    end
end

function tagcounts(query, a...; kw...)
    ts = Notmuch.notmuch_json("search", "--output=tags", a..., query; kw...)
    [ (tag=t, count=parse(Int,chomp(
        Notmuch.notmuch(
            "count", "($query) and tag:$t"; kw...))))
          for t in ts ]
end

using Dates
function date_query(from,to)
    function unixstring(x)
        convert(Int64,round(datetime2unix(round(x, Second))))
    end
    "date:@$(unixstring(from))..@$(unixstring(to))"
end

function count_timespan(q, a...; kw...)
    function query_timestamp(q, b...)
        ns = notmuch_search(Thread,q,b...; limit=1, kw...)
        ##@info "q" q b ns[1].timestamp
        ##dump(ns[1])
        ns[1].timestamp
    end
    c = notmuch_count(q, a...; kw...)
    c == 0 && return nothing
    (
        from = query_timestamp(q,"--sort=oldest-first"),
        to = query_timestamp(q,"--sort=newest-first"),
        count = c
    )
end

function binary_search(monotoneinc::Function, query; lt=<, low, high, eps=0.001, maxiter = 1000)
    middle(l, h) = round(Int, (l + h)//2)
    iter = 0
    ##@info "bins" low high
    while low <= high && iter < maxiter
        mid = middle(low, high)
        midv = monotoneinc(mid)
        if lt(midv, query-eps)
            low = mid
        elseif lt(midv, query+eps)
            return mid
        else
            high = mid
        end
        iter = iter + 1
    end
    low 
end

function time_counts(q, a...; target=1000, eps = 10, maxiter = 10, kw...)
    span = count_timespan(q, a...; kw...)
    to = span.to
    from = span.from
    r = [span]
    ##@info "?" to from 
    opt = binary_search(
        target; low = Dates.value(to-to)
        , high = Dates.value(to-from)
        , eps=eps
        , maxiter = maxiter) do delta
            neu = notmuch_count("($q) and ($(date_query(to-Millisecond(delta),to)))", a...; kw...)
            push!(r, (from=to-Millisecond(delta), to=to, count = neu))
            neu
        end

    (probes = r
     , from = to-Millisecond(opt), to = to)
end
                  

function time_counts_(q, a...; target=1000, kw...)
    span = count_timespan(q, a...; kw...)
    r = [span]
    # Ziel: reduziere data.grundgehalt solange bis 
    # arbeitgeberkosten_iteration == arbeitgeberkosten_aktuell
    query = target
    to = span.to
    from = span.from
    let days = Dates.value(to-from), doopt = true, eps = 1, low = Dates.value(to-to), high = Dates.value(to-from)
        @info "binary search optimierung" days to  
        while doopt
            @show neu = notmuch_count(@show "($q) and ($(date_query(to-Millisecond(days),to)))", a...; kw...)
            queryneu = neu
            push!(r, (from=to-Millisecond(days), to=to, count=neu))
            if queryneu - query > eps # teurer geworden, grundgehalt adaptiv reduzieren 
                @debug " $(days/1000/60/60/24) verringern"
                high = days
                days = (days + low / 2.0)
            elseif queryneu - query < -eps
                @debug " $(days/1000/60/60/24) erhöhen"
                low = days
                days = ( days + high ) / 2
            else
                doopt = false
            end
            #altgrundgehalt = neu.grundgehalt
        end
    end
    r
end

"""
    notmuch_address(q, a...; target=1000, kw...)

call `notmuch address`.
Notmuch adress collection can take long and collect a long list of addresses when run on 100ks of messages.
`notmuch_address` does a binary search to limits the time range to match `target` messages. 

TODO: currently the maximum date is fixed, and the most recent `target` commands are returned.

From the man page:

       Search  for  messages  matching the given search terms, and display
       the addresses from them. Duplicate addresses are filtered out.

       See notmuch-search-terms(7) for details of the supported syntax for
       <search-terms>.

       Supported options for address include

       --format=(json|sexp|text|text0)
              Presents  the results in either JSON, S-Expressions, newline
              character separated plain-text (default), or null  character
              separated  plain-text  (compatible  with  xargs(1) -0 option
              where available).

       --format-version=N
              Use the specified structured output format version. This  is
              intended  for programs that invoke notmuch(1) internally. If
              omitted, the latest supported version will be used.

       --output=(sender|recipients|count|address)
              Controls which information appears in the output.  This  op‐
              tion  can  be given multiple times to combine different out‐
              puts.  When neither --output=sender nor  --output=recipients
              is given, --output=sender is implied.

              sender Output all addresses from the From header.

                     Note: Searching for sender should be much faster than
                     searching for recipients,  because  sender  addresses
                     are cached directly in the database whereas other ad‐
                     dresses need to be fetched from message files.

              recipients
                     Output all addresses from the To, Cc and Bcc headers.

              count  Print the count of how many times was the address en‐
                     countered during search.

                     Note:  With  this  option, addresses are printed only
                     after the whole search is  finished.  This  may  take
                     long time.

              address
                     Output  only  the email addresses instead of the full
                     mailboxes with names and email addresses. This option
                     has no effect on the JSON or S-Expression output for‐
                     mats.

       --deduplicate=(no|mailbox|address)
              Control the deduplication of results.

              no     Output all occurrences of addresses in  the  matching
                     messages. This is not applicable with --output=count.

              mailbox
                     Deduplicate  addresses based on the full, case sensi‐
                     tive name and email address, or mailbox. This is  ef‐
                     fectively  the  same  as  piping the --deduplicate=no
                     output to sort | uniq, except for the  order  of  re‐
                     sults. This is the default.

              address
                     Deduplicate  addresses  based on the case insensitive
                     address part of the  mailbox.  Of  all  the  variants
                     (with  different  name or case), print the one occur‐
                     ring most frequently among the matching messages.  If
                     --output=count  is specified, include all variants in
                     the count.

       --sort=(newest-first|oldest-first)
              This option can be used to present results in either chrono‐
              logical  order (oldest-first) or reverse chronological order
              (newest-first).

              By default, results will be displayed in reverse chronologi‐
              cal  order,  (that  is, the newest results will be displayed
              first).

              However, if either --output=count  or  --deduplicate=address
              is  specified,  this  option is ignored and the order of the
              results is unspecified.

       --exclude=(true|false)
              A message is called "excluded" if it matches  at  least  one
              tag  in  search.exclude_tags that does not appear explicitly
              in the search terms. This option specifies whether  to  omit
              excluded messages in the search process.

              The  default  value,  true,  prevents excluded messages from
              matching the search terms.

              false allows excluded messages to match search terms and ap‐
              pear in displayed results.

"""
function notmuch_address(q, a...; target=1000, kw...)
    if target !== nothing
        tc = time_counts(q; target=target, kw... ).probes
        span=tc[end]
        from = span.from
        to = span.to
        timec = date_query(from,to)
        q_ = "($q) and ($timec)"
        (timespan_counts = tc
         , address = notmuch_json( :address, a...,  q_; kw..., log=true))
    else
        (timespan_counts = []
         , address = notmuch_json( :address, a...,  q; kw..., log=true))
    end
end
export notmuch_address


"""
    notmuch_show(query, x...; body = true, entire_thread=false, kw...)
    notmuch_show(T::Union{Type,Function}, x...; kw...)

`notmuch_search` for `query` and return `notmuch show` for each resulting thread.
(This filtering through threads returns not too long list of first results. You can use `limit` and `offset` keywords.)

With first argument `f::Union{Type,Function}` each result is converted with calling `f`, otherwise JSON is returned.

For user `kw...` see [`userENV`](@ref).


From the man page:
       Shows all messages matching the search terms.

       See notmuch-search-terms(7) for details of the supported syntax for
       <search-terms>.

       The messages will be grouped and sorted based on the threading (all
       replies  to a particular message will appear immediately after that
       message in date order). The output is not indented by default,  but
       depth  tags are printed so that proper indentation can be performed
       by a post-processor (such as the emacs interface to notmuch).

       Supported options for show include

       --entire-thread=(true|false)
              If true, notmuch show outputs all messages in the thread  of
              any  message matching the search terms; if false, it outputs
              only the matching messages.  For  --format=json  and  --for‐
              mat=sexp  this defaults to true. For other formats, this de‐
              faults to false.

       --format=(text|json|sexp|mbox|raw)

              text (default for messages)
                     The default plain-text format  has  all  text-content
                     MIME parts decoded. Various components in the output,
                     (message, header, body, attachment, and  MIME  part),
                     will  be  delimited  by  easily-parsed  markers. Each
                     marker consists of a Control-L character (ASCII deci‐
                     mal  12),  the name of the marker, and then either an
                     opening or closing brace, ('{'  or  '}'),  to  either
                     open  or  close  the  component. For a multipart MIME
                     message, these parts will be nested.

              json   The output is formatted with Javascript Object  Nota‐
                     tion (JSON). This format is more robust than the text
                     format for automated processing. The nested structure
                     of  multipart  MIME  messages  is reflected in nested
                     JSON output. By default JSON output includes all mes‐
                     sages  in  a  matching  thread;  that is, by default,
                     --format=json sets --entire-thread.  The  caller  can
                     disable    this    behaviour    by    setting   --en‐
                     tire-thread=false.  The JSON output is always encoded
                     as UTF-8 and any message content included in the out‐
                     put will be charset-converted to UTF-8.

              sexp   The output is  formatted  as  the  Lisp  s-expression
                     (sexp)  equivalent  of the JSON format above. Objects
                     are formatted as property lists whose keys  are  key‐
                     words  (symbols preceded by a colon). True is format‐
                     ted as t and both false and  null  are  formatted  as
                     nil.  As  for JSON, the s-expression output is always
                     encoded as UTF-8.

              mbox   All matching messages are output in the  traditional,
                     Unix  mbox format with each message being prefixed by
                     a line beginning with "From " and a blank line  sepa‐
                     rating each message. Lines in the message content be‐
                     ginning with "From " (preceded by zero  or  more  '>'
                     characters)  have  an additional '>' character added.
                     This reversible escaping is  termed  "mboxrd"  format
                     and described in detail here:
                        http://homepage.ntlworld.com/jonathan.deboynepollard/FGA/mail-mbox-formats.html

              raw (default if --part is given)
                     Write the raw bytes of the given MIME part of a  mes‐
                     sage to standard out. For this format, it is an error
                     to specify a query that matches more  than  one  mes‐
                     sage.

                     If  the  specified  part is a leaf part, this outputs
                     the body of the part after performing content  trans‐
                     fer  decoding  (but  no  charset conversion). This is
                     suitable for saving attachments, for example.

                     For a multipart or message part, the output  includes
                     the  part  headers as well as the body (including all
                     child parts). No decoding is performed because multi‐
                     part  and  message parts cannot have non-trivial con‐
                     tent transfer encoding. Consumers of this may need to
                     implement MIME decoding and similar functions.

       --format-version=N
              Use  the specified structured output format version. This is
              intended for programs that invoke notmuch(1) internally.  If
              omitted, the latest supported version will be used.

       --part=N
              Output  the  single decoded MIME part N of a single message.
              The search terms must match only a single  message.  Message
              parts are numbered in a depth-first walk of the message MIME
              structure, and are  identified  in  the  'json',  'sexp'  or
              'text' output formats.

              Note  that even a message with no MIME structure or a single
              body part still has two MIME parts: part 0 is the whole mes‐
              sage (headers and body) and part 1 is just the body.

       --verify
              Compute  and  report  the validity of any MIME cryptographic
              signatures found in  the  selected  content  (e.g.,  "multi‐
              part/signed"  parts).  Status  of  the signature will be re‐
              ported (currently  only  supported  with  --format=json  and
              --format=sexp),  and  the  multipart/signed part will be re‐
              placed by the signed data.

       --decrypt=(false|auto|true|stash)
              If true, decrypt any MIME encrypted parts found in  the  se‐
              lected  content  (e.g., "multipart/encrypted" parts). Status
              of the decryption will be reported (currently only supported
              with  --format=json and --format=sexp) and on successful de‐
              cryption the multipart/encrypted part will  be  replaced  by
              the decrypted content.

              stash  behaves  like true, but upon successful decryption it
              will also stash the message's session key in  the  database,
              and  index  the cleartext of the message, enabling automatic
              decryption in the future.

              If auto, and a session key is already known for the message,
              then  it  will be decrypted, but notmuch will not try to ac‐
              cess the user's keys.

              Use false to avoid even automatic decryption.

              Non-automatic decryption (stash or true, in the absence of a
              stashed  session  key) expects a functioning gpg-agent(1) to
              provide any needed credentials. Without one, the  decryption
              will fail.

              Note: setting either true or stash here implies --verify.

              Here is a table that summarizes each of these policies:

                      ┌─────────────┬───────┬──────┬──────┬───────┐
                      │             │ false │ auto │ true │ stash │
                      ├─────────────┼───────┼──────┼──────┼───────┤
                      │Show cleart‐ │       │ X    │ X    │ X     │
                      │ext if  ses‐ │       │      │      │       │
                      │sion  key is │       │      │      │       │
                      │already      │       │      │      │       │
                      │known        │       │      │      │       │
                      ├─────────────┼───────┼──────┼──────┼───────┤
                      │Use   secret │       │      │ X    │ X     │
                      │keys to show │       │      │      │       │
                      │cleartext    │       │      │      │       │
                      ├─────────────┼───────┼──────┼──────┼───────┤
                      │Stash    any │       │      │      │ X     │
                      │newly recov‐ │       │      │      │       │
                      │ered session │       │      │      │       │
                      │keys,  rein‐ │       │      │      │       │
                      │dexing  mes‐ │       │      │      │       │
                      │sage      if │       │      │      │       │
                      │found        │       │      │      │       │
                      └─────────────┴───────┴──────┴──────┴───────┘

              Note: --decrypt=stash requires write access to the database.
              Otherwise, notmuch show operates entirely in read-only mode.

              Default: auto

       --exclude=(true|false)
              Specify whether to omit  threads  only  matching  search.ex‐
              clude_tags  from the search results (the default) or not. In
              either case the excluded message will be marked with the ex‐
              clude flag (except when output=mbox when there is nowhere to
              put the flag).

              If --entire-thread is specified then  complete  threads  are
              returned  regardless  (with the excluded flag being set when
              appropriate) but threads that only match in an excluded mes‐
              sage are not returned when --exclude=true.

              The default is --exclude=true.

       --body=(true|false)
              If  true  (the  default) notmuch show includes the bodies of
              the messages in the output; if false,  bodies  are  omitted.
              --body=false is only implemented for the text, json and sexp
              formats and it is incompatible with --part > 0.

              This is useful if the  caller  only  needs  the  headers  as
              body-less output is much faster and substantially smaller.

       --include-html
              Include  "text/html"  parts as part of the output (currently
              only supported with --format=text, --format=json and  --for‐
              mat=sexp).  By  default, unless --part=N is used to select a
              specific part or  --include-html  is  used  to  include  all
              "text/html"  parts, no part with content type "text/html" is
              included in the output.

       A common use of notmuch show is to display a single thread of email
       messages.  For  this,  use a search term of "thread:<thread-id>" as
       can be seen in the first column of output from the  notmuch  search
       command.

"""
function notmuch_show(query, x...; body = true, entire_thread=false, offset = 0, limit = LIMIT, kw...)
    tids = [ t.thread for t in notmuch_search(query, x...; offset = offset, limit = limit, kw...) ]
    isempty(tids) && return []
    ##@debuginfo "show" query x tids
    threadq = join("thread:" .* tids, " or ")
    notmuch_json(:show, x..., "--body=$body", "--entire-thread=$(entire_thread)",
                 "($query) and ($threadq)"; kw...)
end
    
notmuch_show(T::ToF, x...; kw...) = T(notmuch_show(x...; kw...))
export notmuch_show

"""
    notmuch_tree(x...; body = false, entire_thread=false, kw...)
    notmuch_tree(T::Union{Type,Function}, x...; kw...)

Parsimonous tree query for fetching structure, convenience query for 
[`notmuch_show`](@ref)

With first argument `f::Union{Type,Function}` each result is converted with calling `f`, otherwise JSON is returned.

For user `kw...` see [`userENV`](@ref).
"""
notmuch_tree(x...; body = false, entire_thread=false, kw...) =
    notmuch_show(x...; body = body, entire_thread=entire_thread, kw...)
notmuch_tree(T::ToF, x...; kw...) = T(notmuch_tree(x...; kw...))
export notmuch_tree




export TagChange, notmuch_tag
"""
    TagChange(prefixtag::AbstractString)
    TagChange(prefix::AbstractString, tag::AbstractString)

Prefix is either "+" for adding or "-" for removing a tag.
"""
struct TagChange
    prefix::String
    tag::String
    function TagChange(prefix, tag)
        @assert prefix in ["+","-"]
        new(prefix,tag)
    end
end

function TagChange(tag)
    TagChange(tag[1:1], tag[2:end])
end

Base.isequal(x::TagChange, y::TagChange) =
    x.tag == y.tag

Base.show(io::IO, x::TagChange) =
    print(io, x.prefix, x.tag)

using CombinedParsers
elmail_api_tag_subject = Sequence(Either("+", "-"), !Repeat1(CharNotIn(" ")), " tag ", integer_base(10), " ", !Repeat(AnyChar())) do v
    (query = v[6], rule = TagChange(v[1],v[2]), count = v[4])
end;

function tag_history(; kw...)
    [ (;elmail_api_tag_subject(x.headers.Subject)..., date = x.timestamp)
      for x in flatten(notmuch_show("tag:autotag"; body = false, kw...))
          ]
end

"""
    notmuch_tag(batch::Pair{<:AbstractString,<:AbstractString}...; kw...)
    notmuch_tag(batch::Vector{Pair{String,TagChange}}; kw...)

Tag `query => tagchange` entries in `batch` mode.

Spaces in tags are supported, but other query string encodings for [`notmuch tag`](https://manpages.ubuntu.com/manpages//bionic/man1/notmuch-tag.1.html) are currently not.

For user `kw...` see [`userENV`](@ref).
"""
function notmuch_tag(batch::Vector{Pair{String,TagChange}}; kw...)
    ##cd(@show paths.home)
    open(
        Notmuch.notmuch_cmd(
            "tag", "--batch"; kw...
        ),
        "w", stdout) do io
            for (q, tc) in batch
                @debug "tag $q" tc
                # println(tc.prefix,
                #         replace(tc.tag, " " => "%20")
                #         , " -- ", q)
                println(io, tc.prefix,
                        replace(tc.tag, " " => "%20")
                        , " -- ", q)
            end
            # close(io)
        end
    ##noENV!()
end
notmuch_tag(batch::Pair{<:AbstractString,<:AbstractString}...; kw...) =
    notmuch_tag([q => TagChange(x) for (q,x) in batch]; kw...)



using SMTPClient
export rfc_mail
function rfc_mail(; from, to=String[], cc=String[], bcc=String[], subject, body, replyto="", message_id = "", in_reply_to="", references="", date = now(), attachments = String[], tags = String[], kw... )
    ts = [ "#$tag" for tag in tags
              if !(tag in ["inbox", "unread", "new", "flagged","draft","draftversion","attachment"])]
    io = SMTPClient.get_body(
        to, from,
        subject * ( isempty(ts) ? "" : "   " * join(ts, " ")),
        body; cc=cc,
        bcc=bcc,
        replyto=replyto,
        messageid=message_id,
        inreplyto=in_reply_to,
        references=references,
        date=date,
        attachments=attachments
    )
    s = String(take!(io))
end
export rfc_mail

"""
    notmuch_insert(mail; folder="juliatest")

Insert `mail` as a mail file into `notmuch` (see `notmuch insert`).
Writes a file and changes tags in xapian.
"""
function notmuch_insert(mail; tags = ["new"], folder="elmail", kw...)
    open(
        Notmuch.notmuch_cmd(
            "insert", "--create-folder" ,"--folder=$folder",
            "-new",
            ["+"*p for p in tags]...;
            kw...
                ),
        "w", stdout) do io
            println(io,mail)
        end
end
export notmuch_insert


include("Show.jl")

include("msmtp.jl")

function notmuch_config(; kw... )
    env = userENV(; kw...)
    cfg_file = joinpath(env["HOME"], ".notmuch-config")
    parse_notmuch_cfg()(read(cfg_file, String))
end

export parse_notmuch_config
function parse_notmuch_cfg()
    line = !Atomic(Sequence(1, !re"[^\n]+", "\n"))
    section = Sequence(2,"[", !re"[^]]+", "]", whitespace)
    comment = Sequence(2,re"#+ *", !re"[^\n]*", "\n")
    function splitter(key)
        Sequence(
            key, re" *= *",
            join(!re"[^;\n]+",";"), "\n") do v
                (key = Symbol(key), value = v[3])
            end
    end
    setting =
        Either(
            splitter("tags"),
            splitter("exclude_tags"),
            splitter("other_email"),
            Sequence(:key => !word, re" *= *", :value => line)
        )
    whitespace_newline = !re" *\n"
    #
    Repeat(Either(
        Sequence(
            section,
            Repeat(setting)) do v
                sect,set = v
                Symbol(sect) => Dict(
                    [ (Symbol(k.key) => k.value)
                      for k in set
                          if k !== nothing ]...
                              )
            end,
        Repeat1(
            Either(
                comment,
                whitespace_newline)) do v
                    nothing
                end
    )) do v
        Dict(filter(x -> x!==nothing, v)...)
    end
end



end
