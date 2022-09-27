# Base Alpine Linux based image with OpenJDK JRE only
FROM julia:1.7
# copy application WAR (with libraries inside)
run mkdir /usr/local/webhooks
COPY . /root/Notmuch
COPY msmtp-runqueue.sh /usr/share/doc/msmtp/examples/msmtpqueue/
RUN chmod +x /usr/share/doc/msmtp/examples/msmtpqueue/msmtp-runqueue.sh
RUN apt-get update
RUN apt-get install -y bzip2
RUN apt-get install -y gpgv dh-elpa-helper dirmngr distro-info-data elpa-notmuch emacsen-common gnupg gnupg-l10n gnupg-utils gpg gpg-agent gpg-wks-client gpg-wks-server gpgconf gpgsm gsasl-common libassuan0 libexpat1 libglib2.0-0 libglib2.0-data libgmime-3.0-0 libgpgme11 libgpm2 libgsasl7 libicu67 libidn11 libksba8 libmpdec3 libncursesw6 libnotmuch5 libnpth0 libntlm0 libpython3-stdlib libpython3.9-minimal libpython3.9-stdlib libreadline8 libsecret-1-0 libsecret-common libsqlite3-0 libtalloc2 libxapian30 libxml2 lsb-release media-types msmtp notmuch offlineimap offlineimap3 pinentry-curses python3 python3-distro python3-imaplib2 python3-minimal python3.9 python3.9-minimal readline-common sensible-utils shared-mime-info ucf xdg-user-dirs
RUN julia --project=/root/Notmuch -e 'using Pkg; println(pwd()); Pkg.add(url="https://github.com/gkappler/SMTPClient.jl"); Pkg.instantiate();'
# specify default command
CMD ["/root/Notmuch/bin/server"]
