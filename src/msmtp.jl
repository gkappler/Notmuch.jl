export msmtp_runqueue!

function msmtp_runqueue!(; kw...)
    paths = userENV!(; kw...)
    cd(paths.workdir)
    r = try
        read(`./msmtp-runqueue.sh -C $(paths.maildir)/.msmtprc`, String)
    catch e
        @error "offlineimap error" e
    end
    noENV!()
    r
end

function msmtp(
    rfc;
    ## todo: parse from file!
    msmtp_sender = env_msmtp_sender(),
    mail_file = Dates.format(now(),"yyyy-mm-dd-HH.MM.SS"),
    user = nothing,
    mail_dir = if user !== nothing
        joinpath(ENV["HOMES"], user, ".msmtpqueue")
    else
        expanduser("~/.msmtpqueue")
    end
    )
    open(joinpath(mail_dir, "$mail_file.msmtp"), "w") do io
        println(io, "-oi -f $msmtp_sender -t")
    end
    dt, tz = Dates.format(now(), DateFormat("e, d u Y HH:MM:SS")), get(ENV, "TIMEZONE", "+0100")
    @info "sendme" rfc
    open(joinpath(mail_dir, "$mail_file.mail"), "w") do io
        println(io, rfc)
    end
end

# function msmtp_daemon(sleep_seconds=5)
#     mdir = expanduser("~/.msmtpqueue/")
#     if !isdir(mdir)
#         mkdir(mdir)
#     end
#     let config = expanduser("~/.msmtprc")
#         if !isfile(config)
#             open(config, "w") do io
#                 print(io, """
#     account elmail
#     host $(env_msmtp_host())
#     from $(env_msmtp_sender())
#     tls on
#     tls_certcheck off
#     auth on
#     user $(env_msmtp_user())
#     password $(env_msmtp_password())
#     logfile $(env_msmtp_log())
#     """)
#             end
#         end    
#     end
#     while true
#         itr = readdir(mdir)
#         if !isempty(itr)
#             try
#                 @show run(`/usr/share/doc/msmtp/examples/msmtpqueue/msmtp-runqueue.sh`)
#                 @show run(`/usr/share/doc/msmtp/examples/msmtpqueue/msmtp-runqueue.sh`)
#             catch e
#             end
#         end
#         sleep(sleep_seconds)
#     end
# end

function msmtp_config_string(; account, host, from, user, password, log = "$from.log")
    """
    account $account
    host $(host)
    from $(from)
    tls on
    tls_certcheck off
    auth on
    user $(user)
    password $(password)
    logfile $(logfile)
    """
end

function msmtp_config!()
    let config = expanduser("~/.msmtprc")
        if !isfile(config)
            open(config, "w") do io
                print(io, """
    account noreplyhandelsregister
    host $(env_msmtp_host())
    from $(env_msmtp_sender())
    tls on
    tls_certcheck off
    auth on
    user $(env_msmtp_user())
    password $(env_msmtp_password())
    logfile $(env_msmtp_log())
    """)
            end
        end    
    end
end
