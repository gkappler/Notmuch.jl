(pwd() != @__DIR__) && cd(@__DIR__) # allow starting app from bin/ dir

using ElMail
const UserApp = ElMail
ElMail.main()
