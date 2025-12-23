import Config

if config_env() == :dev do
  config :git_ops,
    mix_project: Mix.Project.get!(),
    repository_url: Mix.Project.config()[:source_url],
    types: [tidbit: [hidden?: true], important: [header: "Important Changes"]],
    github_handle_lookup?: true,
    version_tag_prefix: "v",
    manage_mix_version?: true,
    manage_readme_version: true
end
