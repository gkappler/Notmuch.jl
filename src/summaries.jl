
"""
This function `count_timespan` returns the timestamp for the first and last
elements and the total count of a notmuch search.

@param q    The notmuch query string.
@param a    Additional arguments to pass to the notmuch search command.
@param kw   Keywords to pass to the notmuch search command.

The function `query_timestamp` retrieves the timestamp for a specific notmuch query.

@return     If the count is zero, the function will return nothing. 
            Otherwise, it returns a tuple containing:
            - `from`: Timestamp of the oldest query result,
            - `to`: Timestamp of the newest query result,
            - `count`: The total count of the query result
"""
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
    span === nothing && return nothing
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
    query = target
    to = span.to
    from = span.from
    let days = Dates.value(to-from), doopt = true, eps = 1, low = Dates.value(to-to), high = Dates.value(to-from)
        @info "binary search optimierung" days to  
        while doopt
            @show neu = notmuch_count(@show "($q) and ($(date_query(to-Millisecond(days),to)))", a...; kw...)
            queryneu = neu
            push!(r, (from=to-Millisecond(days), to=to, count=neu))
            if queryneu - query > eps # 
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

function summary(q,a...; kw...)
    (count = notmuch_count(q, a...; kw...)
     , to = DataFrame(notmuch_address(q,"--output=recipients", "--output=count", "--deduplicate=address",a...; kw...).address)
     , from = DataFrame(notmuch_address(q,"--output=count", "--deduplicate=address",a...; kw...).address)
     , tags = DataFrame(tagcounts(q,a...; kw...))
     )
end

function print_summary(io::IO,q,a...; kw...)
    s = summary(q,a...; kw...)

    frm = DataFrame(s.from)
    println(io,"From:")
    sort!(frm,:count)
    println(filter(r->r.count>1,select(frm, [:address, :count])))
    println(join(filter(r->r.count==1,select(frm, [:address, :count])).address, ", "))


    to = DataFrame(s.to)
    println(io,"To:")
    sort!(to,:count)
    println(filter(r->r.count>1,select(to, [:address, :count])))
    println(join(filter(r->r.count==1,select(to, [:address, :count])).address, ", "))

    tags = DataFrame(s.tags)
    println(io,"tags:")
    sort!(tags,:count)
    println(tags)

    for a in sort(s.to; by=e->e.count)
    end
end

function print_rules()
    my_mails = [ e.from  for e in msmtp_config()]
    from_me = join([ "from:$x" for x in my_mails], " or ")
    blacklist = "(tag:spam or tag:advertisement)"
    nc = notmuch_count("tag:new and not $blacklist")
    uc = notmuch_count("tag:unread and not $blacklist")
    print("Notmuch.jl ")
    printstyled(nc," new",color=:green)
    print(" and ")
    printstyled(uc," unread",color=:light_blue)
    println(" mail.")
    trules = apply_rules("from:elmail_api_tag")
    trulesdf = [
        tc => DataFrame([(query= try
                              query_parser(q;trace=true)
                          catch err
                              println(q)
                              println(h)
                              q
                          end
                          , count = sum([event.count for event in h])
                          , events = length(h)
                          , history=h
                                  )
                         for (q,h) in v
                             ])
                for (tc,v) in trules
                    ]
    function print_selected_rules(filt=r -> r.query isa Union{Notmuch.NotmuchLeaf{:fromto},Notmuch.NotmuchLeaf{:from}})
        senders = [let seldf = filter(filt, df)
                       seldf[!, :query] = [ x.value for x in seldf.query]
                       sort!(seldf, [:count]; rev=true)
                       tc => seldf
                   end 
                   for (tc, df)  in (trulesdf)]
        
        for (tc, senderdf) in sort(senders, by=first)
            if !isempty(senderdf)
                println(tc)
                show(stdout,senderdf; row_labels=nothing, eltypes=false, allrows=true,summary=false)
                println()
                ## pretty_table(senderdf)
            end
        end
    end
    println("\n\n## Sender Rules")
    print_selected_rules(r -> r.query isa Union{Notmuch.NotmuchLeaf{:fromto},Notmuch.NotmuchLeaf{:from}})
    
    println("\n\n## Tag Rules")
    print_selected_rules(r -> r.query isa Union{Notmuch.NotmuchLeaf{:tag}})
    ids = [let seldf = filter(r -> r.query isa Union{Notmuch.NotmuchLeaf{:id}}, df)
               seldf[!, :query] = [ (x.value) for x in seldf.query]
               email = [ Email(x; body=false) for x in seldf.query]
               seldf[!, :from] = [ x === nothing ? nothing : parse(email_parser,x.headers.From;trace=true) for x in email]
               seldf[!, :count] = [ x === nothing ? 0 : notmuch_count("to:$x and ($from_me)") for x in seldf.from]
               seldf[!, :count_from] = [ x === nothing ? 0 : notmuch_count("from:$x") for x in seldf.from]
               ##seldf[!, :count_from_sub] = [ x === nothing ? 0 : notmuch_count("from:$x and subject:\"$(e.headers.Subject)\"") for (e,x) in zip(email,seldf.from)]
               seldf[!, :subject] = [ x === nothing ? nothing : x.headers.Subject for x in email]
               for (r, e) in zip(eachrow(seldf), email)
                   if e !== nothing
                       if tc == TagChange("+spam")
                           if ((r.count>0 && r.count_from>0 && r.from != "info@g-kappler.de" ) ||
                               r.from in ["russia@hotelsrussia.com","station@station.sony.com", "noreply@steampowered.com"])
                               println("false positive ",tc, " ",r.from, " ", e)
                               notmuch_tag("id:$(e.id)" => "-spam")
                           elseif (r.count==0 && r.count_from==1)
                               println("true obsolete positive ",tc, " ",r.from, "\n", e)
                               notmuch_tag("id:$(e.id)" => "-spamaybe")
                           end

                           
                       end
                   end
                   for h in r.history
                       for fn in h.filename
                           trash(fn)
                       end
                   end
               end
               sort!(seldf, [:count, :count_from]; rev=true)
               tc => seldf
           end 
           for (tc, df)  in (trulesdf)]
    
    for (tc, senderdf) in sort(ids, by=first)
        if !isempty(senderdf)
            println(tc)
            show(stdout,senderdf; row_labels=nothing, eltypes=false, allrows=true,summary=false)
            println()
            ## pretty_table(senderdf)
        end
    end
end
