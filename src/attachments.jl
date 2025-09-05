
function attachments(id, x::AbstractVector)
    [ attachments(id,a) for a in x if a !== nothing ]
end

function attachments(id, x::JSON3.Object)
    if hasproperty(x, :body)
        vcat(attachments(id, x.body)...)
    elseif hasproperty(x, :content) && hasproperty(x, Symbol("content-type")) && x["content-type"] in [ "multipart/alternative", "multipart/mixed" ]
            vcat(attachments(id, x.content)...)
    elseif hasproperty(x, Symbol("content-disposition")) && x["content-disposition"] == "attachment"
        (;:message_id => id, (Symbol(replace("$k", "-" =>"_")) => v for (k,v) in  pairs(x))...)
    elseif hasproperty(x, Symbol("content-type")) && x["content-type"] in ["text/html","text/plain"]
        @warn ("dropping $x")
        nothing
    else
        @warn ("invalid $x")
        nothing
    end
end

function attachments(id::String; kw...)
    attachments(id, Notmuch.show(id; body=true, kw...))
end



part(parg, id::String; kw...) =
    notmuch("show", "--part=$parg", "id:$id"; kw...)


@deprecate save(id, att; work_path = pwd(), kw...) save_attachment(id, att; work_path = pwd(), kw...)
function save_attachment(id, att; work_path = pwd(), kw...)
    file = joinpath(work_path, att.filename)
    @debug "writing attachment $file"
    open(file,"w") do io
        print_attachment(io, att; kw...)
    end
    file
end
function print_attachment(io::IO, att; kw...)
    print(io, Notmuch.part(att.id, att.message_id; kw...))
end


function print_attachment(att; kw...)
    print_attachment(stdout, att; kw...)
end
