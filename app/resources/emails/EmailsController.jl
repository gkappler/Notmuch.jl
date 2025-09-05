module EmailsController
using Notmuch
using Genie, Genie.Renderer, Genie.Renderer.Html, Genie.Renderer.Json, SearchLight, Emails

function index()
    html(:emails, :index, emails=notmuch_tree("tags:new"))
    #json(notmuch_tree("tags:new"))
end
 
end
