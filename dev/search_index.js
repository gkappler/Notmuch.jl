var documenterSearchIndex = {"docs":
[{"location":"#Notmuch.jl","page":"Notmuch.jl","title":"Notmuch.jl","text":"","category":"section"},{"location":"#Notmuch-wrappers","page":"Notmuch.jl","title":"Notmuch wrappers","text":"","category":"section"},{"location":"","page":"Notmuch.jl","title":"Notmuch.jl","text":"Notmuch\nNotmuch.notmuch_cmd\nNotmuch.notmuch\nNotmuch.notmuch_json\nNotmuch.notmuch_count\nNotmuch.notmuch_search\nNotmuch.notmuch_tree\nNotmuch.notmuch_address\nNotmuch.notmuch_show\nNotmuch.notmuch_insert","category":"page"},{"location":"#Notmuch","page":"Notmuch.jl","title":"Notmuch","text":"Notmuch.jl opens maildir email data up for analyses in Julia by providing a julia Cmd wrapper for notmuch mail database supporting arbitrary tags and advanced search.\n\nNotmuch mail indexes emails into a xapian database from a maildir store.\n\nmaildir \n\nis an standard for email datasets.\ncan be smoothly synchronized with an IMAP server by offlineimap.\n\nGenie routes are provided exposing notmuch search as an HTTP API.\n\n\n\n\n\n","category":"module"},{"location":"#Notmuch.notmuch_cmd","page":"Notmuch.jl","title":"Notmuch.notmuch_cmd","text":"notmuch_cmd(command, x...; log=false, kw...)\n\nBuild notmuch command with arguments x....\n\nFor user kw... see userENV.\n\nUsed in notmuch_json and  notmuch.\n\n\n\n\n\n","category":"function"},{"location":"#Notmuch.notmuch","page":"Notmuch.jl","title":"Notmuch.notmuch","text":"notmuch(x...; kw...)\n\nRun notmuch_cmd and return output as String.\n\nSee notmuch_json To get json as a String, provide \"--format=json\" as argument.\n\nFor user kw... see userENV.\n\n\n\n\n\n","category":"function"},{"location":"#Notmuch.notmuch_json","page":"Notmuch.jl","title":"Notmuch.notmuch_json","text":"notmuch_json(command,x...; kw...)\n\nParse notmuch with JSON3.read.\n\nFor user kw... see userENV.\n\n\n\n\n\n","category":"function"},{"location":"#Notmuch.notmuch_count","page":"Notmuch.jl","title":"Notmuch.notmuch_count","text":"notmuch_count(x...; kw...)\n\nfrom the man-page:\n\ncount messages matching the given search terms\n\n   The number of matching messages (or threads) is output to stdout.\n\n   With no search terms, a count of all messages (or threads) in the data‐\n   base will be displayed.\n\n   See notmuch-search-terms(7) for details of  the  supported  syntax  for\n   <search-terms>.\n\n   Supported options for count include\n\n   --output=(messages|threads|files)\n\n          messages\n                 Output  the  number of matching messages. This is the de‐\n                 fault.\n\n          threads\n                 Output the number of matching threads.\n\n          files  Output the number of files associated with matching  mes‐\n                 sages.  This  may  be  bigger than the number of matching\n                 messages due to duplicates (i.e.  multiple  files  having\n                 the same message-id).\n\n   --exclude=(true|false)\n          Specify  whether  to  omit messages matching search.exclude_tags\n          from the count (the default) or not.\n\n   --batch\n          Read queries from a file (stdin by default), one per  line,  and\n          output  the  number of matching messages (or threads) to stdout,\n          one per line. On an empty input line the count of  all  messages\n          (or  threads) in the database will be output. This option is not\n          compatible with specifying search terms on the command line.\n\n   --lastmod\n          Append lastmod (counter for number of database updates) and UUID\n          to  the output. lastmod values are only comparable between data‐\n          bases with the same UUID.\n\n   --input=<filename>\n          Read input from given  file,  instead  of  from  stdin.  Implies\n          --batch.\n\n\n\n\n\n","category":"function"},{"location":"#Notmuch.notmuch_search","page":"Notmuch.jl","title":"Notmuch.notmuch_search","text":"notmuch_search(query, x...; offset=0, limit=5, kw...)\nnotmuch_search(T::Union{Type,Function}, x...; kw...)\n\nSearch notmuch and return threads json Vector.\n\nWith first argument f::Union{Type,Function} each result is converted with calling f, otherwise JSON is returned.\n\nFor user kw... see userENV.\n\nFrom the man page:\n\n   Search for messages matching the given search terms, and display as\n   results the threads containing the matched messages.\n\n   The output consists of one line per thread, giving a thread ID, the\n   date of the newest  (or  oldest,  depending  on  the  sort  option)\n   matched  message  in the thread, the number of matched messages and\n   total messages in the thread, the names of all participants in  the\n   thread, and the subject of the newest (or oldest) message.\n\n   See notmuch-search-terms(7) for details of the supported syntax for\n   <search-terms>.\n\n   Supported options for search include\n\n   --format=(json|sexp|text|text0)\n          Presents the results in either JSON, S-Expressions,  newline\n          character  separated plain-text (default), or null character\n          separated plain-text (compatible  with  xargs(1)  -0  option\n          where available).\n\n   --format-version=N\n          Use  the specified structured output format version. This is\n          intended for programs that invoke notmuch(1) internally.  If\n          omitted, the latest supported version will be used.\n\n   --output=(summary|threads|messages|files|tags)\n\n          summary\n                 Output  a  summary  of  each  thread with any message\n                 matching the search terms. The summary  includes  the\n                 thread ID, date, the number of messages in the thread\n                 (both the number matched and the total  number),  the\n                 authors  of  the  thread and the subject. In the case\n                 where a thread contains multiple files for some  mes‐\n                 sages, the total number of files is printed in paren‐\n                 theses (see below for an example).\n\n          threads\n                 Output the thread IDs of all threads with any message\n                 matching  the  search  terms,  either  one  per  line\n                 (--format=text), separated by null characters (--for‐\n                 mat=text0),  as  a  JSON array (--format=json), or an\n                 S-Expression list (--format=sexp).\n\n          messages\n                 Output the message IDs of all messages  matching  the\n                 search  terms,  either  one per line (--format=text),\n                 separated by null characters (--format=text0),  as  a\n                 JSON  array  (--format=json),  or  as an S-Expression\n                 list (--format=sexp).\n\n          files  Output the filenames of  all  messages  matching  the\n                 search  terms,  either  one per line (--format=text),\n                 separated by null characters (--format=text0),  as  a\n                 JSON  array  (--format=json),  or  as an S-Expression\n                 list (--format=sexp).\n\n                 Note that each message may  have  multiple  filenames\n                 associated  with  it. All of them are included in the\n                 output (unless limited  with  the  --duplicate=N  op‐\n                 tion). This may be particularly confusing for folder:\n                 or path: searches in a specified  directory,  as  the\n                 messages  may  have  duplicates  in other directories\n                 that are included in the output, although these files\n                 alone would not match the search.\n\n          tags   Output  all  tags that appear on any message matching\n                 the  search  terms,  either  one  per  line   (--for‐\n                 mat=text),   separated  by  null  characters  (--for‐\n                 mat=text0), as a JSON array (--format=json), or as an\n                 S-Expression list (--format=sexp).\n\n   --sort=(newest-first|oldest-first)\n          This option can be used to present results in either chrono‐\n          logical order (oldest-first) or reverse chronological  order\n          (newest-first).\n\n          Note:  The  thread  order will be distinct between these two\n          options (beyond being simply reversed). When sorting by old‐\n          est-first  the  threads will be sorted by the oldest message\n          in each thread, but when sorting by newest-first the threads\n          will be sorted by the newest message in each thread.\n\n          By default, results will be displayed in reverse chronologi‐\n          cal order, (that is, the newest results  will  be  displayed\n          first).\n\n   --offset=[-]N\n          Skip  displaying  the first N results. With the leading '-',\n          start at the Nth result from the end.\n\n   --limit=N\n          Limit the number of displayed results to N.\n\n   --exclude=(true|false|all|flag)\n          A message is called \"excluded\" if it matches  at  least  one\n          tag  in  search.exclude_tags that does not appear explicitly\n          in the search terms. This option specifies whether  to  omit\n          excluded messages in the search process.\n\n          true (default)\n                 Prevent  excluded  messages  from matching the search\n                 terms.\n\n          all    Additionally prevent excluded messages from appearing\n                 in  displayed  results,  in effect behaving as though\n                 the excluded messages do not exist.\n\n          false  Allow excluded messages to match search terms and ap‐\n                 pear  in  displayed  results.  Excluded  messages are\n                 still marked in the relevant outputs.\n\n          flag   Only has an effect when --output=summary. The  output\n                 is  almost  identical to false, but the \"match count\"\n                 is the number of matching  non-excluded  messages  in\n                 the  thread,  rather than the number of matching mes‐\n                 sages.\n\n   --duplicate=N\n          For --output=files, output the Nth filename associated  with\n          each  message  matching  the  query  (N is 1-based). If N is\n          greater than the number of files associated  with  the  mes‐\n          sage, don't print anything.\n\n          For  --output=messages,  only output message IDs of messages\n          matching the search terms that have at least N filenames as‐\n          sociated with them.\n\n          Note  that this option is orthogonal with the folder: search\n          prefix. The prefix matches messages based on filenames. This\n          option filters filenames of the matching messages.\n\n\n\n\n\n","category":"function"},{"location":"#Notmuch.notmuch_tree","page":"Notmuch.jl","title":"Notmuch.notmuch_tree","text":"notmuch_tree(x...; body = false, entire_thread=false, kw...)\nnotmuch_tree(T::Union{Type,Function}, x...; kw...)\n\nParsimonous tree query for fetching structure, convenience query for  notmuch_show\n\nWith first argument f::Union{Type,Function} each result is converted with calling f, otherwise JSON is returned.\n\nFor user kw... see userENV.\n\n\n\n\n\n","category":"function"},{"location":"#Notmuch.notmuch_address","page":"Notmuch.jl","title":"Notmuch.notmuch_address","text":"notmuch_address(q, a...; target=1000, kw...)\n\ncall notmuch address. Notmuch adress collection can take long and collect a long list of addresses when run on 100ks of messages. notmuch_address does a binary search to limits the time range to match target messages. \n\nTODO: currently the maximum date is fixed, and the most recent target commands are returned.\n\nFrom the man page:\n\n   Search  for  messages  matching the given search terms, and display\n   the addresses from them. Duplicate addresses are filtered out.\n\n   See notmuch-search-terms(7) for details of the supported syntax for\n   <search-terms>.\n\n   Supported options for address include\n\n   --format=(json|sexp|text|text0)\n          Presents  the results in either JSON, S-Expressions, newline\n          character separated plain-text (default), or null  character\n          separated  plain-text  (compatible  with  xargs(1) -0 option\n          where available).\n\n   --format-version=N\n          Use the specified structured output format version. This  is\n          intended  for programs that invoke notmuch(1) internally. If\n          omitted, the latest supported version will be used.\n\n   --output=(sender|recipients|count|address)\n          Controls which information appears in the output.  This  op‐\n          tion  can  be given multiple times to combine different out‐\n          puts.  When neither --output=sender nor  --output=recipients\n          is given, --output=sender is implied.\n\n          sender Output all addresses from the From header.\n\n                 Note: Searching for sender should be much faster than\n                 searching for recipients,  because  sender  addresses\n                 are cached directly in the database whereas other ad‐\n                 dresses need to be fetched from message files.\n\n          recipients\n                 Output all addresses from the To, Cc and Bcc headers.\n\n          count  Print the count of how many times was the address en‐\n                 countered during search.\n\n                 Note:  With  this  option, addresses are printed only\n                 after the whole search is  finished.  This  may  take\n                 long time.\n\n          address\n                 Output  only  the email addresses instead of the full\n                 mailboxes with names and email addresses. This option\n                 has no effect on the JSON or S-Expression output for‐\n                 mats.\n\n   --deduplicate=(no|mailbox|address)\n          Control the deduplication of results.\n\n          no     Output all occurrences of addresses in  the  matching\n                 messages. This is not applicable with --output=count.\n\n          mailbox\n                 Deduplicate  addresses based on the full, case sensi‐\n                 tive name and email address, or mailbox. This is  ef‐\n                 fectively  the  same  as  piping the --deduplicate=no\n                 output to sort | uniq, except for the  order  of  re‐\n                 sults. This is the default.\n\n          address\n                 Deduplicate  addresses  based on the case insensitive\n                 address part of the  mailbox.  Of  all  the  variants\n                 (with  different  name or case), print the one occur‐\n                 ring most frequently among the matching messages.  If\n                 --output=count  is specified, include all variants in\n                 the count.\n\n   --sort=(newest-first|oldest-first)\n          This option can be used to present results in either chrono‐\n          logical  order (oldest-first) or reverse chronological order\n          (newest-first).\n\n          By default, results will be displayed in reverse chronologi‐\n          cal  order,  (that  is, the newest results will be displayed\n          first).\n\n          However, if either --output=count  or  --deduplicate=address\n          is  specified,  this  option is ignored and the order of the\n          results is unspecified.\n\n   --exclude=(true|false)\n          A message is called \"excluded\" if it matches  at  least  one\n          tag  in  search.exclude_tags that does not appear explicitly\n          in the search terms. This option specifies whether  to  omit\n          excluded messages in the search process.\n\n          The  default  value,  true,  prevents excluded messages from\n          matching the search terms.\n\n          false allows excluded messages to match search terms and ap‐\n          pear in displayed results.\n\n\n\n\n\n","category":"function"},{"location":"#Notmuch.notmuch_show","page":"Notmuch.jl","title":"Notmuch.notmuch_show","text":"notmuch_show(query, x...; body = true, entire_thread=false, kw...)\nnotmuch_show(T::Union{Type,Function}, x...; kw...)\n\nReturn notmuch show.\n\nWith first argument f::Union{Type,Function} each result is converted with calling f, otherwise JSON is returned.\n\nFor user kw... see userENV.\n\nFrom the man page:        Shows all messages matching the search terms.\n\n   See notmuch-search-terms(7) for details of the supported syntax for\n   <search-terms>.\n\n   The messages will be grouped and sorted based on the threading (all\n   replies  to a particular message will appear immediately after that\n   message in date order). The output is not indented by default,  but\n   depth  tags are printed so that proper indentation can be performed\n   by a post-processor (such as the emacs interface to notmuch).\n\n   Supported options for show include\n\n   --entire-thread=(true|false)\n          If true, notmuch show outputs all messages in the thread  of\n          any  message matching the search terms; if false, it outputs\n          only the matching messages.  For  --format=json  and  --for‐\n          mat=sexp  this defaults to true. For other formats, this de‐\n          faults to false.\n\n   --format=(text|json|sexp|mbox|raw)\n\n          text (default for messages)\n                 The default plain-text format  has  all  text-content\n                 MIME parts decoded. Various components in the output,\n                 (message, header, body, attachment, and  MIME  part),\n                 will  be  delimited  by  easily-parsed  markers. Each\n                 marker consists of a Control-L character (ASCII deci‐\n                 mal  12),  the name of the marker, and then either an\n                 opening or closing brace, ('{'  or  '}'),  to  either\n                 open  or  close  the  component. For a multipart MIME\n                 message, these parts will be nested.\n\n          json   The output is formatted with Javascript Object  Nota‐\n                 tion (JSON). This format is more robust than the text\n                 format for automated processing. The nested structure\n                 of  multipart  MIME  messages  is reflected in nested\n                 JSON output. By default JSON output includes all mes‐\n                 sages  in  a  matching  thread;  that is, by default,\n                 --format=json sets --entire-thread.  The  caller  can\n                 disable    this    behaviour    by    setting   --en‐\n                 tire-thread=false.  The JSON output is always encoded\n                 as UTF-8 and any message content included in the out‐\n                 put will be charset-converted to UTF-8.\n\n          sexp   The output is  formatted  as  the  Lisp  s-expression\n                 (sexp)  equivalent  of the JSON format above. Objects\n                 are formatted as property lists whose keys  are  key‐\n                 words  (symbols preceded by a colon). True is format‐\n                 ted as t and both false and  null  are  formatted  as\n                 nil.  As  for JSON, the s-expression output is always\n                 encoded as UTF-8.\n\n          mbox   All matching messages are output in the  traditional,\n                 Unix  mbox format with each message being prefixed by\n                 a line beginning with \"From \" and a blank line  sepa‐\n                 rating each message. Lines in the message content be‐\n                 ginning with \"From \" (preceded by zero  or  more  '>'\n                 characters)  have  an additional '>' character added.\n                 This reversible escaping is  termed  \"mboxrd\"  format\n                 and described in detail here:\n                    http://homepage.ntlworld.com/jonathan.deboynepollard/FGA/mail-mbox-formats.html\n\n          raw (default if --part is given)\n                 Write the raw bytes of the given MIME part of a  mes‐\n                 sage to standard out. For this format, it is an error\n                 to specify a query that matches more  than  one  mes‐\n                 sage.\n\n                 If  the  specified  part is a leaf part, this outputs\n                 the body of the part after performing content  trans‐\n                 fer  decoding  (but  no  charset conversion). This is\n                 suitable for saving attachments, for example.\n\n                 For a multipart or message part, the output  includes\n                 the  part  headers as well as the body (including all\n                 child parts). No decoding is performed because multi‐\n                 part  and  message parts cannot have non-trivial con‐\n                 tent transfer encoding. Consumers of this may need to\n                 implement MIME decoding and similar functions.\n\n   --format-version=N\n          Use  the specified structured output format version. This is\n          intended for programs that invoke notmuch(1) internally.  If\n          omitted, the latest supported version will be used.\n\n   --part=N\n          Output  the  single decoded MIME part N of a single message.\n          The search terms must match only a single  message.  Message\n          parts are numbered in a depth-first walk of the message MIME\n          structure, and are  identified  in  the  'json',  'sexp'  or\n          'text' output formats.\n\n          Note  that even a message with no MIME structure or a single\n          body part still has two MIME parts: part 0 is the whole mes‐\n          sage (headers and body) and part 1 is just the body.\n\n   --verify\n          Compute  and  report  the validity of any MIME cryptographic\n          signatures found in  the  selected  content  (e.g.,  \"multi‐\n          part/signed\"  parts).  Status  of  the signature will be re‐\n          ported (currently  only  supported  with  --format=json  and\n          --format=sexp),  and  the  multipart/signed part will be re‐\n          placed by the signed data.\n\n   --decrypt=(false|auto|true|stash)\n          If true, decrypt any MIME encrypted parts found in  the  se‐\n          lected  content  (e.g., \"multipart/encrypted\" parts). Status\n          of the decryption will be reported (currently only supported\n          with  --format=json and --format=sexp) and on successful de‐\n          cryption the multipart/encrypted part will  be  replaced  by\n          the decrypted content.\n\n          stash  behaves  like true, but upon successful decryption it\n          will also stash the message's session key in  the  database,\n          and  index  the cleartext of the message, enabling automatic\n          decryption in the future.\n\n          If auto, and a session key is already known for the message,\n          then  it  will be decrypted, but notmuch will not try to ac‐\n          cess the user's keys.\n\n          Use false to avoid even automatic decryption.\n\n          Non-automatic decryption (stash or true, in the absence of a\n          stashed  session  key) expects a functioning gpg-agent(1) to\n          provide any needed credentials. Without one, the  decryption\n          will fail.\n\n          Note: setting either true or stash here implies --verify.\n\n          Here is a table that summarizes each of these policies:\n\n                  ┌─────────────┬───────┬──────┬──────┬───────┐\n                  │             │ false │ auto │ true │ stash │\n                  ├─────────────┼───────┼──────┼──────┼───────┤\n                  │Show cleart‐ │       │ X    │ X    │ X     │\n                  │ext if  ses‐ │       │      │      │       │\n                  │sion  key is │       │      │      │       │\n                  │already      │       │      │      │       │\n                  │known        │       │      │      │       │\n                  ├─────────────┼───────┼──────┼──────┼───────┤\n                  │Use   secret │       │      │ X    │ X     │\n                  │keys to show │       │      │      │       │\n                  │cleartext    │       │      │      │       │\n                  ├─────────────┼───────┼──────┼──────┼───────┤\n                  │Stash    any │       │      │      │ X     │\n                  │newly recov‐ │       │      │      │       │\n                  │ered session │       │      │      │       │\n                  │keys,  rein‐ │       │      │      │       │\n                  │dexing  mes‐ │       │      │      │       │\n                  │sage      if │       │      │      │       │\n                  │found        │       │      │      │       │\n                  └─────────────┴───────┴──────┴──────┴───────┘\n\n          Note: --decrypt=stash requires write access to the database.\n          Otherwise, notmuch show operates entirely in read-only mode.\n\n          Default: auto\n\n   --exclude=(true|false)\n          Specify whether to omit  threads  only  matching  search.ex‐\n          clude_tags  from the search results (the default) or not. In\n          either case the excluded message will be marked with the ex‐\n          clude flag (except when output=mbox when there is nowhere to\n          put the flag).\n\n          If --entire-thread is specified then  complete  threads  are\n          returned  regardless  (with the excluded flag being set when\n          appropriate) but threads that only match in an excluded mes‐\n          sage are not returned when --exclude=true.\n\n          The default is --exclude=true.\n\n   --body=(true|false)\n          If  true  (the  default) notmuch show includes the bodies of\n          the messages in the output; if false,  bodies  are  omitted.\n          --body=false is only implemented for the text, json and sexp\n          formats and it is incompatible with --part > 0.\n\n          This is useful if the  caller  only  needs  the  headers  as\n          body-less output is much faster and substantially smaller.\n\n   --include-html\n          Include  \"text/html\"  parts as part of the output (currently\n          only supported with --format=text, --format=json and  --for‐\n          mat=sexp).  By  default, unless --part=N is used to select a\n          specific part or  --include-html  is  used  to  include  all\n          \"text/html\"  parts, no part with content type \"text/html\" is\n          included in the output.\n\n   A common use of notmuch show is to display a single thread of email\n   messages.  For  this,  use a search term of \"thread:<thread-id>\" as\n   can be seen in the first column of output from the  notmuch  search\n   command.\n\n\n\n\n\n","category":"function"},{"location":"#Notmuch.notmuch_insert","page":"Notmuch.jl","title":"Notmuch.notmuch_insert","text":"notmuch_insert(mail; folder=\"juliatest\")\n\nInsert mail as a mail file into notmuch (see notmuch insert). Writes a file and changes tags in xapian.\n\n\n\n\n\n","category":"function"},{"location":"#Tagging","page":"Notmuch.jl","title":"Tagging","text":"","category":"section"},{"location":"","page":"Notmuch.jl","title":"Notmuch.jl","text":"Notmuch.TagChange\nNotmuch.notmuch_tag","category":"page"},{"location":"#Notmuch.TagChange","page":"Notmuch.jl","title":"Notmuch.TagChange","text":"TagChange(prefixtag::AbstractString)\nTagChange(prefix::AbstractString, tag::AbstractString)\n\nPrefix is either \"+\" for adding or \"-\" for removing a tag.\n\n\n\n\n\n","category":"type"},{"location":"#Notmuch.notmuch_tag","page":"Notmuch.jl","title":"Notmuch.notmuch_tag","text":"notmuch_tag(batch::Pair{<:AbstractString,<:AbstractString}...; kw...)\nnotmuch_tag(batch::Vector{Pair{String,TagChange}}; kw...)\n\nTag query => tagchange entries in batch mode.\n\nSpaces in tags are supported, but other query string encodings for notmuch tag are currently not.\n\nFor user kw... see userENV.\n\n\n\n\n\n","category":"function"},{"location":"#Multiple-users","page":"Notmuch.jl","title":"Multiple users","text":"","category":"section"},{"location":"","page":"Notmuch.jl","title":"Notmuch.jl","text":"Notmuch.userENV","category":"page"},{"location":"#Notmuch.userENV","page":"Notmuch.jl","title":"Notmuch.userENV","text":"userENV(; workdir= get(ENV,\"NOTMUCHJL\",pwd()), homes = joinpath(workdir, \"home\"), user = nothing)\n\nConstruct environment Dict(\"HOME\" => joinpath(homes,user), \"MAILDIR\" => joinpath(homes,user,\"maildir\")).\n\nIf user === nothing use  Dict(\"HOME\" => get(ENV,\"NOHOME\",ENV[\"HOME\"]), \"MAILDIR\" => get(ENV,\"NOMAILDIR\", ENV[\"MAILDIR\"])).\n\nSee notmuch_cmd, offlineimap!, and msmtp_runqueue!\n\n\n\n\n\n","category":"function"},{"location":"#OfflineImap-and-MSMTP","page":"Notmuch.jl","title":"OfflineImap and MSMTP","text":"","category":"section"},{"location":"","page":"Notmuch.jl","title":"Notmuch.jl","text":"Notmuch.msmtp_runqueue!\nNotmuch.msmtp\nNotmuch.offlineimap!\nNotmuch.checkpath!","category":"page"},{"location":"#Notmuch.msmtp_runqueue!","page":"Notmuch.jl","title":"Notmuch.msmtp_runqueue!","text":"msmtp_runqueue!(; kw...)\n\nSend all messages with ./msmtp-runqueue.sh with  config file set to joinpath(env[\"HOME\"], \".msmtprc\").\n\nFor user kw... see userENV.\n\n\n\n\n\n","category":"function"},{"location":"#Notmuch.msmtp","page":"Notmuch.jl","title":"Notmuch.msmtp","text":"msmtp(rfc; msmtp_sender = env_msmtp_sender(),  mail_file = Dates.format(now(),\"yyyy-mm-dd-HH.MM.SS\"),  kw... )\n\nWrite rfc formatted mail to a $mail_file.mail in joinpath(env[\"HOME\"], \".msmtpqueue\") and msmtp arguments \"-oi -f msmtp_sender -t for sending in joinpath(mail_dir mail_file.msmtp\").\n\nFor user kw... see userENV.\n\ntodo: msmtp_sender should be parsed from rfc content!\n\n\n\n\n\n","category":"function"},{"location":"#Notmuch.offlineimap!","page":"Notmuch.jl","title":"Notmuch.offlineimap!","text":"offlineimap!(; cfg = \".offlineimaprc\", kw...)\n\nRun system Cmd offlineimap and then notmuch_new. Returns output of both.\n\nFor user kw... see userENV.\n\n\n\n\n\n","category":"function"},{"location":"#Notmuch.checkpath!","page":"Notmuch.jl","title":"Notmuch.checkpath!","text":"checkpath!(x)\n\n!isdir(x) && mkpath(x)\n\n\n\n\n\n","category":"function"},{"location":"#Helpers","page":"Notmuch.jl","title":"Helpers","text":"","category":"section"},{"location":"#Julia-email-types","page":"Notmuch.jl","title":"Julia email types","text":"","category":"section"},{"location":"","page":"Notmuch.jl","title":"Notmuch.jl","text":"Notmuch.Emails\nNotmuch.Email\nNotmuch.Headers\nNotmuch.PlainContent\nNotmuch.WithReplies","category":"page"},{"location":"#Notmuch.Emails","page":"Notmuch.jl","title":"Notmuch.Emails","text":"Emails(x)\n\nTransformation function to pass to notmuch_show.\n\njulia> notmuch_tree(Emails, \"tag:elmail\")\n\n\n\n\n\n","category":"function"},{"location":"#Notmuch.Email","page":"Notmuch.jl","title":"Notmuch.Email","text":"Email\n\nstruct wrapping notmuch json email format.\n\n\n\n\n\n","category":"type"},{"location":"#Notmuch.Headers","page":"Notmuch.jl","title":"Notmuch.Headers","text":"Headers\n\nstruct wrapping notmuch json header format.\n\n\n\n\n\n","category":"type"},{"location":"#Notmuch.PlainContent","page":"Notmuch.jl","title":"Notmuch.PlainContent","text":"PlainContent{type}\n\nstruct wrapping notmuch json content format.\n\n\n\n\n\n","category":"type"},{"location":"#Notmuch.WithReplies","page":"Notmuch.jl","title":"Notmuch.WithReplies","text":"WithReplies{M,R}\n\ntype to hold a nested reply tree. notmuch_tree\n\n\n\n\n\n","category":"type"},{"location":"#Genie-helper-functions","page":"Notmuch.jl","title":"Genie helper functions","text":"","category":"section"},{"location":"","page":"Notmuch.jl","title":"Notmuch.jl","text":"Notmuch.Key\nNotmuch.omitq\nNotmuch.optionstring","category":"page"},{"location":"#Notmuch.Key","page":"Notmuch.jl","title":"Notmuch.Key","text":"Key = Union{AbstractString,Symbol}\n\nGenie GET and POST key type.\n\n\n\n\n\n","category":"type"},{"location":"#Notmuch.omitq","page":"Notmuch.jl","title":"Notmuch.omitq","text":"omitq(x)\nomitqtags(x)\n\nq is the query parameter for the search argument in notmuch.\n\nWhere it applies (notmuch tag) tags is the tag flag query +add and -remove.\n\nOther query parameters are passed as is to notmuch as --setting=value.\n\n\n\n\n\n","category":"function"},{"location":"#Notmuch.optionstring","page":"Notmuch.jl","title":"Notmuch.optionstring","text":"optionstring(...)\n\nInternally constructs notmuch Cmd arguments from API queries. Works but should be simplified.\n\n\n\n\n\n","category":"function"}]
}
