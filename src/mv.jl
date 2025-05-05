export notmuch_mv
notmuch_mv(query::AbstractString, a...; kw...) =
    notmuch_mv(x -> replace(x, a...), query; kw...)


function notmuch_mv(query::AbstractString, p::Pair{<:AbstractString,<:AbstractString}; kw...)
    notmuch_mv(x -> replace(replace(x, p),r"(cur|new)/.*/([^/]*)" => s"\1/\2"), query * " and path:\"$(p.first)**\""; kw...)
end


function notmuch_mv(p::Pair{<:AbstractString,<:AbstractString}; kw...)
    rq = replace(p.first, "/" => "\\/", "." => "\\.")
    notmuch_mv(x -> replace(x, p), "folder:/$rq/"; kw...)
end

function notmuch_mv(p::Pair{<:Regex}; kw...)
    rq = replace(p.first.pattern, "\$" => "\$", "/" => "\\/")
    notmuch_mv(x -> replace(x, p), "folder:/$rq/"; kw...)
end

function ynp(x)
    println(x)
    if readline(stdin) in ["y", "yes"]
        true
    else
        false
    end
end
function notmuch_folders(kw...)
end
function notmuch_mv(f::Function, query;
                    dryrun = true, do_mkdir = ynp,
                    kw...)
    @info "moving" query
    touched = false
    tasks = Dict()    
    for mailid in notmuch_search(query, "--output=messages"; kw...) ##"--output=files"
        mail = Email(mailid)
        ##println(mail)
        for file in notmuch_search("id:$mailid", "--output=files"; kw...)
            #println(file)
            tf = f(file)
            if tf !== nothing && tf != file
                l = get!(tasks, dirname(tf)) do
                    []
                end
                push!(l, (mail,file) => basename(tf))
            end
        end
    end
    #print(tasks)
    for (folder, files) in tasks
        if isfile(folder)
            error("file base name target?")
        else
            if !isdir(folder)
                @warn "target folder does not exist. Cannot move $(length(files)) files" folder files
                do_mkdir("Make path $folder?") && begin
                    root,sub = dirname(folder),basename(folder)
                    subs = ["cur", "new", "tmp"]
                    if sub in subs
                        for s in subs
                            mkpath(joinpath(root,s))
                        end
                    else
                        error("invalid maildir path $folder")
                    end
                end
            end
            if isdir(folder)
                @info "moving $(length(files)) files to folder" folder
                if dryrun
                    for ((mail,file),tf) in files
                        println(IOContext(stdout, :compact => true), "# move ", mail)
                        println("mv \"$file\" \"$tf\"")
                    end
                else
                    ids = [f[1][1] for f in files]
                    for ((mail,file),tf) in files
                        try
                            @info "moving " mail file joinpath(folder,tf)
                            mv(file,joinpath(folder,tf), force=true)
                            touched = true
                        catch e
                            println(e)
                            #print(String(read(file)))
                        end
                    end

                    function log_mail(ids)
                        return nothing
                        if length(ids)==1
                            (folder = "elmail/tag", tags = [ TagChange("+tag") ], 
                             rfc_mail = rfc_mail(from = from, to = to, 
                                                 in_reply_to = "<" * ids[1].id * ">",
                                                 subject = "$tc tag", content= Plain(body)))
                        else
                            (folder = "elmail/autotag", tags = [ TagChange("+autotag") ],
                             rfc_mail = rfc_mail(from = from, to = to, 
                                                 subject = "$tc tag $(length(ids)) $qq", 
                                                 content = 
                                                     MultiPart(:mixed,
                                                               [ Plain(body),
                                                                 SMTPClient.MimeContent{MIME{Symbol("notmuch/ids")}}(
                                                                     "moved from $source to $target.sh",
                                                                     ## 
                                                                     join([tc.prefix * replace(tc.tag, " " => "%20") * " -- id:" * id
                                                                           for id in ids ]
                                                                          ,"\n")
                                                                 )
                                                                 ])
                                                 ))
                        end
                    end
                    insert = log_mail(ids)
                    #println(rfc)
                if insert !== nothing
                    # @info "tag $(length(ids)) $q => tc, log ids"
                    # notmuch_insert(insert.rfc_mail
                    #                ; tags = [ insert.tags..., TagChange("-inbox"), TagChange("-new") ]
                    #                , folder= insert.folder
                    #                , kw...
                    #                    )
                else
                    #@info "tag $(length(ids)) $q => tc"
                end
                end
            else
            end
        end
    end
    touched && notmuch("new"; kw...)
end
