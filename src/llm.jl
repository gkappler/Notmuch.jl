using PromptingTools
import PromptingTools: render, SystemMessage, UserMessage

schema = PromptingTools.OpenAISchema() # also accessible as the default schema `PT.PROMPT_SCHEMA`

function llm_reply(message_ids)
    es = [Email(id, body=true) for id in message_ids ]
    isempty(e) && error("no mail  found")
    
    conversation = conversation = [
        PromptingTools.SystemMessage("""
Act as a helpful AI assistant for {{primary_email}}.
Provide information that is
important, relevant and helpful
to write a reply.
When drafting a reply match the tone of {{primary_email}}.

Also play through possible next steps
of the other involved participants.
    """)
        (
            PromptingTools.UserMessage(
                e.headers.Subject *"\n\n"*
                    join(e.body,"\n")
                ; name= string(e.headers.From))
            for e in es )...
                ]

    messages = render(schema, conversation)

    aigenerate(conversation; primary_email=primary_email())
end


mailthread = NotmuchLeaf{:thread}
function notmuch_tag_sender(message_id, tag; kw...)
end
function notmuch_context(message_id, tag; kw...)
    e = Email(message_id; body=true, kw...)
    # reply_to = Email(e.headers.Reply_To; body=true, kw...)
    threads = notmuch_search("id:"*e.id, "--output=threads";kw...)
    mailthread.(threads)
end




template_feedback = """
            You are a polymath scientist and researcher, and can provide insights. Be specific but brief.

Provide a helpful and specific answer, constructive suggestions,  or continuation, and a constructive and critical feedback how to improve my texts regarding helpfullnes, logic, rhythm, and melody.

Include honest constructive realistic feedback.
Suggest low hanging fruit and frugal next steps.
Double check for a consistent logic flow.

{{headers}}}
{{body}}}


Consider this background context:
{{context}}}

Consider that these tasks are already done:
{{done}}}

"""

template_plan = """
            Create an actionable step-step-plan to achieve:
            {{{goal}}}
            {{details}}}

            The plan should be actionable next in this context:
            {{context}}}
            Consider these tasks are already done.
            {{done}}}

            Be as brief as possible.
            Suggest established open source solutions and market leaders where appropriate.
            Use concise bullet points.
            Include most important
            recommendations when necessary.
            Adhere to markdown format.
"""

template_search_threads = """
            Generate a Notmuch query to find relevant messages related to this draft:
            Consider what kind of related messages are relevant
            based on the draft content.
            Consider all notmuch search terms, `from:`, `to:`,
            `tag`,
            and specific search terms
            -- but sparsely!
            Use `date:` ranges (remember notmuch date format is unix timestamps prefixed with '@')
            only when requested.
            
            ---

            {{draft_header}}
            {{draft_body}}

            ---

            My common tags are
             {{{tags}}}

            Be machine-readable and return only the notmuch query string (e.g., 'to:alice@example.com'). No encapsulation as code or comment.
            """

template_background_search = """
            Create executive summaries for all involved persons.
            {{{goal}}}

            Lay out communalities and common interests
            regarding
            {{details}}}

            What would interest anyone about these things I can offer:
            {{offer}}}

            How to best approach them in this context:
            {{{context}}}
            """

function llm_drafts(id= "request"; limit=10,kw...)
    email = Email(id; body=true)

    search_query = aigenerate(
        template_search_threads,
        draft_header=email.headers,
        draft_body=email.body,
        tags = join(Notmuch.search_tags("not tag:deleted")," ")
    )

    
    ids = notmuch_ids("(" * search_query.content * ") and not tag:done and not id:$(email.id)"; limit=limit,
                      kw...)
    done_ids = notmuch_ids("(" * search_query.content * ") and tag:done and not id:$(email.id)";limit=limit,
                      kw...)
    email_separator = "\n\n----\n"
    context = string(email) * email_separator *
        join([Email(cid; body=true) for cid in ids],
             email_separator)
    done = 
        join([Email(cid; body=true) for cid in done_ids],
             email_separator)
    @info "query llm" email context done
    
    feedback_query = aigenerate(
        template_feedback,
        headers=email.headers,
        body=email.body,
        context= context,
        done= done
    )

    subject, bodymd = split(feedback_query.content*"\n\n","\n", limit=2)
    notmuch_insert(rfc_mail(
        subject; body=bodymd,
        to = [],
        in_reply_to = email.id,
        date = now(),
        message_id = email.id*"-aigent-plan"))

    
    plan_query = aigenerate(
        template_plan,
        goal=email.headers,
        details=email.body,
        context= context,
        done= done
    )

    subject, bodymd = split(plan_query.content*"\n\n","\n", limit=2)
    notmuch_insert(rfc_mail(
        subject; body=bodymd,
        to = [],
        in_reply_to = email.id,
        date = now(),
        message_id = email.id*"-aigent-plan"))

    
    background_query = aigenerate(
        template_background_search,
        goal=email.headers,
        ressources = email.body,
        context= context,
        offer= done
    )

    subject, bodymd = split(background_query.content*"\n\n","\n", limit=2)
    notmuch_insert(rfc_mail(
        subject; body=bodymd,
        to = [],
        in_reply_to = email.id,
        date = now(),
        message_id = email.id*"-aigent-background"))
   
end

