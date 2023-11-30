contenttype = begin
    tspecials = CharNotIn('(', ')', '<', '>', '@', # Must be in
                          ',', ';', ':', '\\', '\'', # ; quoted-string,
                          '/', '[', ']', '?', '.', # ; to use within
                          '=') # ; parameter values
    token = Repeat1(CharNotIn(tspecials, ' ', '\t', '\n', '\r'))
    # CHAR except SPACE, CTLs, or tspecials>"
    attribute = token
    value = Either(token, quoted-string)
    xtoken = Sequence("X-", token)
    type = Either(
        "application","audio",
        "image", "message",
        "multipart", "text",
        "video", x-token)
    subtype := token
    parameter := attribute "=" value
    Sequence(type, "/", subtype,
             Repeat(";", parameter))
end
