(pwd() != @__DIR__) && cd(@__DIR__) # allow starting app from bin/ dir

using Pkg
Pkg.activate(".");
#Pkg.add(path="..");Pkg.add(url="https://github.com/gkappler/SMTPClient.jl");Pkg.instantiate();

using ElMail
const UserApp = ElMail
ElMail.main()
