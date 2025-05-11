
export notmuch_mv
notmuch_mv(query::AbstractString, a...; kw...) =
    notmuch_mv(x -> replace(x, a...), query; kw...)


function notmuch_mv(query::AbstractString, p::Pair{<:AbstractString,<:AbstractString}; kw...)
    notmuch_mv(x -> replace(replace(x, p),r"(cur|new)/.*/([^/]*)" => s"\1/\2"), query * " and path:\"$(p.first)**\""; kw...)
end


function notmuch_mv(p::Pair{<:AbstractString,<:AbstractString}; kw...)
    rq = replace(p.first, "/" => "\\/", "." => "\\.")
    notmuch_mv(x -> replace(x, p), "folder:/$rq/"; kw...)
end

function notmuch_mv(p::Pair{<:Regex}; kw...)
    rq = replace(p.first.pattern, "\$" => "\$", "/" => "\\/")
    notmuch_mv(x -> replace(x, p), "folder:/$rq/"; kw...)
end

function ynp(x)
    println(x)
    if readline(stdin) in ["y", "yes"]
        true
    else
        false
    end
end
function notmuch_folders(kw...)
end


# Helper function to ensure target directory exists and is valid Maildir
function ensure_maildir_target(folder::String, do_mkdir_prompt::Function)
    if isfile(folder)
        error("Target path '$folder' is a file, expected a directory.")
    end

    if !isdir(folder)
        @warn "Target folder does not exist: $folder"
        # Use the provided prompt function (e.g., ynp)
        if do_mkdir_prompt("Make path $folder and ensure Maildir structure?")
            root = dirname(folder)
            sub = basename(folder)
            # Standard Maildir subdirectories
            maildir_subs = ["cur", "new", "tmp"]

            if sub in maildir_subs
                # Assume 'folder' is like /path/to/maildir/.Archive/cur
                # We need to ensure /path/to/maildir/.Archive/cur, new, tmp exist
                # The parent directory of 'folder' is the Maildir folder itself (e.g., .Archive)
                maildir_root = root
                try
                    # Create all standard subdirectories within the parent
                    for s in maildir_subs
                        mkpath(joinpath(maildir_root, s))
                    end
                    @info "Created Maildir structure at $maildir_root"
                    # After creation, check if the specific target sub-directory exists
                    if !isdir(folder)
                        # This should ideally not happen if mkpath succeeded
                        error("Failed to create target directory '$folder' even after mkpath.")
                    end
                    return true # Directory created/ensured
                catch e
                    @error "Failed to create directory structure for $folder" exception=(e, catch_backtrace())
                    return false # Failed to create
                end
            else
                # If the target's basename isn't cur, new, or tmp, the original code errored.
                # Maintain this behavior.
                error("Target folder '$folder' does not end in 'cur', 'new', or 'tmp'. Not a standard Maildir target according to original logic.")
                # If general directory creation were desired:
                # try
                #     mkpath(folder)
                #     @info "Created directory $folder"
                #     return true
                # catch e
                #     @error "Failed to create directory $folder" exception=(e, catch_backtrace())
                #     return false
                # end
            end
        else
            # User chose not to create the directory
            @warn "Directory creation skipped by user for folder: $folder"
            return false # User skipped creation
        end
    end
    # Directory already exists
    return true
end

# Helper function to process the actual move for a single folder
function move_files_for_folder(folder::String, files_to_move::Vector, dryrun::Bool)
    local any_moved_in_this_folder = 0
    num_files = length(files_to_move)

    if num_files == 0
        return 0 # Nothing to do
    end

    action_verb = dryrun ? "Would move" : "Moving"
    @info "$action_verb $num_files files to folder: $folder"

    # Example structure of element in files_to_move:
    # (original_file="path/to/source", target_basename="target_name", mail=Email(...))

    if dryrun
        for move_task in files_to_move
            original_file = move_task.original_file
            target_basename = move_task.target_basename
            mail = move_task.mail # Assuming mail object has useful info like an ID
            target_full_path = joinpath(folder, target_basename)
            # Use mail.id if available, otherwise show minimal info
            mail_info = hasattr(mail, :id) ? mail.id : repr(mail)
            println(IOContext(stdout, :compact => true), "# Dry run: Move mail: ", mail_info)
            println("mv \"$original_file\" \"$target_full_path\"")
        end
        # In dry run, we report potential success but don't change 'any_moved_in_this_folder'
        return 0 # No actual moves performed
    else
        # Perform actual moves
        # Collect IDs if needed for hypothetical logging later
        # mail_ids = [task.mail.id for task in files_to_move if hasattr(task.mail, :id)]

        for move_task in files_to_move
            original_file = move_task.original_file
            target_basename = move_task.target_basename
            mail = move_task.mail
            target_full_path = joinpath(folder, target_basename)

            mail_info = hasattr(mail, :id) ? mail.id : repr(mail)

            try
                @info "Moving mail $mail_info : $original_file -> $target_full_path"
                # force=true overwrites existing file at destination
                mv(original_file, target_full_path, force=true)
                any_moved_in_this_folder += 1 # Mark that at least one move succeeded
            catch e
                @error "Failed to move file" original_file target_full_path exception=(e, catch_backtrace())
                # Optional: Log content of file that failed to move?
                # try
                #     println("Content of failed file $original_file:\n", String(read(original_file)))
                # catch read_err
                #     @error "Could not read failed file $original_file" exception=(read_err, catch_backtrace())
                # end
            end
        end

        # --- Potential Logging section (based on original commented code) ---
        # This part requires definition of log_mail_operation and likely more context (query, tags etc.)
        # function log_mail_operation(moved_ids, source_query, target_folder_path)
        #     # Placeholder for actual logging implementation (e.g., sending an email)
        #     # Needs access to query, target details, maybe tag info.
        #     println("Logging move of IDs: ", join(moved_ids, ", "), " to ", target_folder_path)
        #     return nothing # Or return data needed for notmuch_insert
        # end
        #
        # if any_moved_in_this_folder == 0 && !isempty(mail_ids)
        #     log_entry = log_mail_operation(mail_ids, "some_query_placeholder", folder) # Needs query context
        #     if log_entry !== nothing
        #         @info "Logging move operation via notmuch insert for $(length(mail_ids)) emails to $folder"
        #         # Example: Assume log_entry has :rfc_mail, :tags, :folder fields
        #         # notmuch_insert(log_entry.rfc_mail; tags=log_entry.tags, folder=log_entry.folder, kw...) # kw needs passing down
        #     end
        # end
        # --- End Logging section ---

    end
    return any_moved_in_this_folder
end


"""
    notmuch_mv(f::Function, query::String; dryrun=true, do_mkdir_prompt=ynp, kw...)

Moves emails matching `query` based on the target path generated by function `f`.

Finds emails using `notmuch search query --output=messages`, then finds the corresponding
files using `notmuch search id:<id> --output=files`. For each file, it computes a
target path using `target_path = f(original_path)`. If the target path is valid and
different from the original, the move is planned.

Moves are grouped by the target directory (`dirname(target_path)`). Before moving,
it checks if the target directory exists. If not, it prompts the user via `do_mkdir_prompt`.
If confirmed, it attempts to create the directory, ensuring standard Maildir subdirs
(`cur`, `new`, `tmp`) if the target directory name itself is one of these (e.g.,
moving to `/path/to/maildir/.Archive/cur`).

If `dryrun` is true, it prints the `mv` commands instead of executing them.
If `dryrun` is false and files are moved, it runs `notmuch new` afterwards to update
the Notmuch database.

# Arguments
- `f::Function`: A function `String -> Union{String, Nothing}`. Takes an email file path,
  returns a new target file path or `nothing`. `nothing` or returning the original path
  skips the move for that file.
- `query::String`: The notmuch query string.

# Keyword Arguments
- `dryrun::Bool = true`: If `true`, simulate moves; if `false`, perform moves.
- `do_mkdir_prompt::Function = ynp`: Function called to confirm creation of non-existent
  target directories. Must return `true` to proceed with creation. Assumes `ynp` (yes/no prompt)
  is defined in the calling scope.
- `kw...`: Additional keyword arguments passed to `notmuch_search` and `notmuch` calls.

# Returns
- `Int`: `true` if files were successfully moved (and `notmuch new` run, if applicable),
          `false` otherwise (including dry runs or if no files needed moving).

# Assumptions
- `notmuch_search`, `notmuch`, `Email`, and `ynp` functions/types are available.
- The `Email` type (if used beyond just passing) potentially has an `.id` field for logging.
"""
function notmuch_mv(f::Function, query::String;
                    dryrun::Bool = true,
                    do_mkdir_prompt::Function = ynp, # Requires ynp or similar to be defined
                    kw...)
    @info "Planning email moves based on query:" query
    if dryrun
        @info "Dry run mode enabled. No files will be moved."
    end

    # Structure to hold planned moves: Dict{TargetDir => Vector[MoveTask]}
    # MoveTask is a NamedTuple: (original_file, target_basename, mail_object)
    MoveTask = NamedTuple{(:original_file, :target_basename, :mail), Tuple{String, String, Any}}
    tasks = Dict{String, Vector{MoveTask}}()

    # Phase 1: Collect and group move tasks
    processed_message_count = 0
    potential_move_count = 0
    for mail_id in notmuch_search(query, "--output=messages"; kw...)
        processed_message_count += 1
        local mail_obj
        try
            # Attempt to create an Email object. Adjust if Email constructor or usage differs.
            # If Email(...) is heavy and only ID is needed, consider alternatives.
            mail_obj = Email(mail_id)
        catch e
            @warn "Could not instantiate Email object for id: $mail_id. Skipping files for this message." exception=(e, catch_backtrace())
            continue # Skip to the next message ID
        end

        # Find file(s) for this specific email ID
        # Note: An email message might span multiple files in some Maildir variants (rare)
        # or if notmuch database is inconsistent. Handle multiple files per ID.
        files_for_id = notmuch_search("id:$mail_id", "--output=files"; kw...)
        if isempty(files_for_id)
             @warn "No files found by notmuch for mail id: $mail_id (Message $processed_message_count)"
             continue
        end

        for original_file_path in files_for_id
            # Basic check if file exists before processing
            if !isfile(original_file_path)
                 @warn "File path from notmuch does not exist, skipping:" original_file_path mail_id=mail_id
                 continue
            end

            target_file_path = try
                f(original_file_path)
            catch e
                @error "Function `f` threw an error for file: $original_file_path" exception=(e, catch_backtrace())
                nothing # Treat error in `f` as skipping this file
            end

            # Check if a valid, different target path was returned
            if target_file_path isa String && target_file_path != original_file_path
                target_dir = dirname(target_file_path)
                target_basename = basename(target_file_path)

                # Validate the generated path components
                if isempty(target_dir) || target_dir == "." || isempty(target_basename)
                    @warn "Generated target path '$target_file_path' has invalid directory or basename, skipping move for:" original_file_path
                    continue
                end

                # Add to tasks, grouped by target directory
                task_list = get!(tasks, target_dir) do
                    Vector{MoveTask}() # Initialize empty vector if key doesn't exist
                end
                push!(task_list, (original_file=original_file_path, target_basename=target_basename, mail=mail_obj))
                potential_move_count += 1
            end
            # Implicit else: if target_file_path is nothing, or same as original, do nothing.
        end
    end

    @info "Finished query processing." processed_message_count=processed_message_count potential_moves=potential_move_count target_directories=length(tasks)

    if isempty(tasks)
        @info "No valid moves identified based on the query and function `f`."
        return false # Nothing to do
    end

    # Phase 2: Execute or simulate moves for each target directory
    overall_success = true # Tracks if all intended operations succeed
    number_of_moves_performed = 0 # Tracks if mv() was called and succeeded

    for (target_dir, files_in_dir) in tasks
        num_files = length(files_in_dir)
        @info "Processing target directory '$target_dir' with $num_files potential move(s)."

        # Ensure the target directory exists and meets criteria (e.g., Maildir structure)
        # This function handles prompts and creation attempts.
        can_proceed = ensure_maildir_target(target_dir, do_mkdir_prompt)

        if can_proceed
            # Attempt to move files to this verified/created directory
            moved_successfully = move_files_for_folder(target_dir, files_in_dir, dryrun)
            if !dryrun && moved_successfully > 0
                number_of_moves_performed += moved_successfully
            elseif !dryrun && moved_successfully == 0 && num_files > 0
                # If it wasn't a dry run, and moves were attempted but failed
                @warn "Some or all moves to directory '$target_dir' may have failed."
                overall_success = false # Mark failure if any move in the batch fails
            end
        else
            # Directory check/creation failed or was skipped by user
            @error "Cannot proceed with moving $num_files files to folder '$target_dir' due to directory setup issues."
            overall_success = false # Cannot proceed, so mark as failure
        end
    end

    # Phase 3: Finalization - Update Notmuch database if needed
    if number_of_moves_performed > 0 && !dryrun
        @info "Moves performed. Running 'notmuch new' to update the database."
        try
            # Execute 'notmuch new' command, passing down keyword arguments
            notmuch("new"; kw...)
            @info "'notmuch new' completed successfully."
            # If we reached here after moves, overall success depends on prior steps
            return overall_success # True if moves happened and no errors above, false otherwise
        catch e
            @error "Failed to run 'notmuch new' after moving files." exception=(e, catch_backtrace())
            return false # Explicit failure due to notmuch update error
        end
    elseif !number_of_moves_performed > 0 && !dryrun
         @info "Execution finished, but no files were actually moved (either due to errors or all moves failed)."
         return false # No moves were successful, or none attempted after errors
    elseif dryrun
         @info "Dry run finished. No changes were made."
         return false # Dry run means no actual success state
    else
         # This case should ideally not be reached if logic is sound
         @info "Finished processing, no moves were triggered or performed."
         return false
    end

    # Fallback return, should be covered by returns inside the if/else block
    return number_of_moves_performed# && overall_success
end
