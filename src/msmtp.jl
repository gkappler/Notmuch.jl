export msmtp_runqueue!

"""
    msmtp_runqueue!(; kw...)

Send all messages with `./msmtp-runqueue.sh` with 
config file set to `joinpath(env["HOME"], ".msmtprc")`.

For user `kw...` see [`userENV`](@ref).
"""
function msmtp_runqueue!(; kw...)
    env = userENV(; kw...)
    r = try
        h = joinpath(env["HOME"], ".msmtprc")
        cmd = Cmd(`./msmtp-runqueue.sh -C $h`;
            env=env
            )
        @debug "sending msmtp..." cmd
        read(cmd,  String)
    catch e
        @error "msmtp-runqueue.sh error" e
    end
    r
end

"""
    msmtp(rfc; msmtp_sender = env_msmtp_sender(),  mailfile = Dates.format(now(),"yyyy-mm-dd-HH.MM.SS"),  kw... )

Write `rfc` formatted mail for sending to a `\$mailfile.mail` in `joinpath(env["HOME"], ".msmtpqueue")` 
and msmtp arguments in `\$mailfile.msmtp`

    -oi -f \$msmtp_sender -t

For user `kw...` see [`userENV`](@ref).

todo: `msmtp_sender` should be parsed from `rfc` content!
"""
function msmtp(rfc; msmtp_sender = env_msmtp_sender(),
               mailfile = Dates.format(now(),"yyyy-mm-dd-HH.MM.SS"), kw... )
    env = userENV(; kw...)
    mail_dir = joinpath(env["HOME"], ".msmtpqueue")
    open(joinpath(mail_dir, "$mailfile.msmtp"), "w") do io
        println(io, "-oi -f $msmtp_sender -t")
    end
    dt, tz = Dates.format(now(), DateFormat("e, d u Y HH:MM:SS")), get(ENV, "TIMEZONE", "+0100")
    mailfile = joinpath(mail_dir, "$mailfile.mail")
    open(mailfile, "w") do io
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
