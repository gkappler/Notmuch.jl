using Genie, Logging

Genie.Configuration.config!(
    server_port                     = 9999,
    server_host                     = "0.0.0.0",
    log_level                       = Logging.Debug,
    log_to_file                     = true,
    server_handle_static_files      = true,
    path_build                      = "build",
    format_julia_builds             = true,
    format_html_output              = true,
    cors_headers                    = Dict(
        "Access-Control-Allow-Origin" => "*",
        "Access-Control-Allow-Headers" => "Content-Type",
        "Access-Control-Allow-Methods" => "GET,POST")
)

ENV["JULIA_REVISE"] = "auto"