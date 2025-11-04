using ReplMaker

function parse_to_query(x)
    x
end

initrepl(parse_to_query, 
         prompt_text="notmuch> ",
         prompt_color = :red, 
         start_key='~', 
         mode_name="notmuch_mode")

function parse_to_expr(s)
           quote Meta.parse($s) end
       end
ReplMaker.initrepl(parse_to_expr, 
                prompt_text="Expr> ",
                prompt_color = :blue, 
                start_key=')', 
                mode_name="Expr_mode")
